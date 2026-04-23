"""Admin CLI for auth-user management.

Runs outside the Flask request cycle so it can be invoked with

    docker compose exec rag-web python -m utils.auth.cli <command> [args]

Available commands: create-user, reset-password, list-users, disable-user,
enable-user, revoke-sessions.

Every command opens its own SQLAlchemy session, commits on success, and
emits a short human-readable summary on stdout. Errors go to stderr with
exit code 1.
"""
from __future__ import annotations

import argparse
import getpass
import secrets
import string
import sys
from datetime import datetime, timezone
from typing import Optional

from .audit import (
    ACCOUNT_DISABLED,
    ACCOUNT_ENABLED,
    PASSWORD_RESET_ADMIN,
    SESSION_REVOKED_OTHERS,
    record_event,
)
from .db import get_engine
from .repos import SessionRepo, UserRepo
from .security import hash_password, validate_password_strength


def _session():
    from sqlalchemy.orm import sessionmaker
    return sessionmaker(bind=get_engine(), future=True, expire_on_commit=False)()


def _generate_password(length: int = 18) -> str:
    alphabet = string.ascii_letters + string.digits + "!#$%&*+-=?@"
    while True:
        pw = "".join(secrets.choice(alphabet) for _ in range(length))
        if validate_password_strength(pw) is None:
            return pw


def _prompt_password(confirm: bool = True) -> str:
    while True:
        pw = getpass.getpass("Password (leave blank to auto-generate): ")
        if not pw:
            return _generate_password()
        err = validate_password_strength(pw)
        if err:
            print(f"  ✗ {err}", file=sys.stderr)
            continue
        if confirm:
            again = getpass.getpass("Confirm: ")
            if again != pw:
                print("  ✗ Passwords did not match", file=sys.stderr)
                continue
        return pw


def _abort(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


# ── Commands ─────────────────────────────────────────────────────────

def cmd_create_user(args: argparse.Namespace) -> None:
    email = args.email.strip().lower()
    display_name = args.display_name.strip() if args.display_name else None

    db = _session()
    try:
        users = UserRepo(db)
        if users.get_by_email(email) is not None:
            _abort(f"user with email {email} already exists")

        if args.password:
            pw = args.password
            err = validate_password_strength(pw)
            if err:
                _abort(err)
            generated = False
        elif args.generate:
            pw = _generate_password()
            generated = True
        else:
            pw = _prompt_password()
            generated = False

        user = users.create(email=email, password=pw, display_name=display_name)
        db.commit()
        print(f"Created user {user.email}  id={user.id}")
        if generated or args.password is None:
            print(f"Temporary password: {pw}")
            print("  (share via a secure out-of-band channel and ask the user to change it)")
    finally:
        db.close()


def cmd_reset_password(args: argparse.Namespace) -> None:
    email = args.email.strip().lower()

    db = _session()
    try:
        users = UserRepo(db)
        user = users.get_by_email(email)
        if user is None:
            _abort(f"no active user with email {email}")

        if args.password:
            pw = args.password
            err = validate_password_strength(pw)
            if err:
                _abort(err)
            generated = False
        elif args.generate:
            pw = _generate_password()
            generated = True
        else:
            pw = _prompt_password()
            generated = False

        users.update_password_hash(user, hash_password(pw))
        revoked = SessionRepo(db).revoke_all_for_user(user.id)
        record_event(
            db,
            PASSWORD_RESET_ADMIN,
            user_id=user.id,
            metadata={"revoked_sessions": revoked, "source": "admin_cli"},
        )
        db.commit()

        print(f"Reset password for {user.email}; revoked {revoked} active session(s).")
        if generated or args.password is None:
            print(f"New password: {pw}")
    finally:
        db.close()


def cmd_list_users(args: argparse.Namespace) -> None:
    from sqlalchemy import select
    from .models import User
    db = _session()
    try:
        stmt = select(User).where(User.deleted_at.is_(None)).order_by(User.created_at.asc())
        rows = list(db.execute(stmt).scalars())
        if not rows:
            print("(no users)")
            return
        for u in rows:
            flag = "active" if u.is_active else "disabled"
            name = f" ({u.display_name})" if u.display_name else ""
            print(f"  {u.id}  {u.email:<40}{name}  {flag}")
    finally:
        db.close()


def _set_user_active(email: str, active: bool, event_type: str) -> None:
    db = _session()
    try:
        users = UserRepo(db)
        user = users.get_by_email(email)
        if user is None:
            _abort(f"no active user with email {email}")
        if user.is_active == active:
            state = "enabled" if active else "disabled"
            print(f"{user.email} is already {state}; nothing to do.")
            return
        user.is_active = active
        revoked = 0
        if not active:
            revoked = SessionRepo(db).revoke_all_for_user(user.id)
        record_event(
            db,
            event_type,
            user_id=user.id,
            metadata={"revoked_sessions": revoked, "source": "admin_cli"},
        )
        db.commit()
        verb = "enabled" if active else "disabled"
        extra = f"; revoked {revoked} session(s)" if not active else ""
        print(f"{verb.capitalize()} {user.email}{extra}.")
    finally:
        db.close()


def cmd_disable_user(args: argparse.Namespace) -> None:
    _set_user_active(args.email.strip().lower(), active=False, event_type=ACCOUNT_DISABLED)


def cmd_enable_user(args: argparse.Namespace) -> None:
    _set_user_active(args.email.strip().lower(), active=True, event_type=ACCOUNT_ENABLED)


def cmd_revoke_sessions(args: argparse.Namespace) -> None:
    email = args.email.strip().lower()
    db = _session()
    try:
        user = UserRepo(db).get_by_email(email)
        if user is None:
            _abort(f"no active user with email {email}")
        revoked = SessionRepo(db).revoke_all_for_user(user.id)
        record_event(
            db,
            SESSION_REVOKED_OTHERS,
            user_id=user.id,
            metadata={"revoked": revoked, "source": "admin_cli"},
        )
        db.commit()
        print(f"Revoked {revoked} active session(s) for {email}.")
    finally:
        db.close()


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="python -m utils.auth.cli",
        description="Auth admin operations for the unified RAG/GraphRAG stack.",
    )
    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("create-user", help="Create a new user account.")
    sp.add_argument("email")
    sp.add_argument("--display-name", help="Optional display name.")
    g = sp.add_mutually_exclusive_group()
    g.add_argument("--password", help="Password (skip interactive prompt).")
    g.add_argument("--generate", action="store_true", help="Generate a strong random password.")
    sp.set_defaults(func=cmd_create_user)

    sp = sub.add_parser("reset-password", help="Reset a user's password; revokes all active sessions.")
    sp.add_argument("email")
    g = sp.add_mutually_exclusive_group()
    g.add_argument("--password", help="New password (skip interactive prompt).")
    g.add_argument("--generate", action="store_true", help="Generate a strong random password.")
    sp.set_defaults(func=cmd_reset_password)

    sp = sub.add_parser("list-users", help="List active user accounts.")
    sp.set_defaults(func=cmd_list_users)

    sp = sub.add_parser("disable-user", help="Deactivate an account and revoke its sessions.")
    sp.add_argument("email")
    sp.set_defaults(func=cmd_disable_user)

    sp = sub.add_parser("enable-user", help="Reactivate a previously disabled account.")
    sp.add_argument("email")
    sp.set_defaults(func=cmd_enable_user)

    sp = sub.add_parser("revoke-sessions", help="Revoke every active session for a user.")
    sp.add_argument("email")
    sp.set_defaults(func=cmd_revoke_sessions)

    return p


def main(argv: Optional[list[str]] = None) -> None:
    args = build_parser().parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
