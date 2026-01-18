"""
Cost tracking utilities for Gemini API usage in VLM formula to LaTeX tool.
Adapted from Paper2Code implementation.
"""

import json
from typing import Dict, List, Any


def cal_gemini_cost(usage_metadata, model_name: str = "gemini-3-flash-preview") -> Dict[str, Any]:
    """
    Calculate cost for Gemini API calls using usage_metadata from response.
    
    Args:
        usage_metadata: The usage_metadata object from Gemini response
                       Contains: prompt_token_count, candidates_token_count, total_token_count
        model_name: The Gemini model name
    
    Returns:
        dict with cost breakdown
    """
    # Gemini 3 Flash pricing per 1M tokens (in USD)
    gemini_pricing = {
        "gemini-3-flash-preview": {"input": 0.50, "output": 3.00},
        "gemini-2.0-flash-exp": {"input": 0.00, "output": 0.00},  # Free tier
    }
    
    # Get pricing for the model (default to gemini-3-flash-preview)
    pricing = gemini_pricing.get(model_name, gemini_pricing["gemini-3-flash-preview"])
    
    # Extract token counts from usage_metadata
    prompt_tokens = usage_metadata.prompt_token_count if usage_metadata else 0
    output_tokens = usage_metadata.candidates_token_count if usage_metadata else 0
    total_tokens = usage_metadata.total_token_count if usage_metadata else 0
    
    # Calculate costs (per 1M tokens)
    input_cost = (prompt_tokens / 1_000_000) * pricing['input']
    output_cost = (output_tokens / 1_000_000) * pricing['output']
    total_cost = input_cost + output_cost
    
    return {
        'model_name': model_name,
        'prompt_tokens': prompt_tokens,
        'input_cost': input_cost,
        'output_tokens': output_tokens,
        'output_cost': output_cost,
        'total_tokens': total_tokens,
        'total_cost': total_cost,
    }


def save_accumulated_cost(accumulated_cost_file: str, cost: float) -> None:
    """
    Save accumulated cost to a JSON file.
    
    Args:
        accumulated_cost_file: Path to the cost file
        cost: Total accumulated cost
    """
    with open(accumulated_cost_file, "w", encoding="utf-8") as f:
        json.dump({"total_cost": cost}, f)


def print_log_gemini_cost(
    usage_metadata,
    model_name: str,
    current_stage: str,
    output_dir: str,
    total_accumulated_cost: float
) -> float:
    """
    Print and log Gemini API cost information.
    
    Args:
        usage_metadata: The usage_metadata object from Gemini response
        model_name: The Gemini model name
        current_stage: Description of the current processing stage
        output_dir: Directory to save the cost log
        total_accumulated_cost: Running total of accumulated costs
    
    Returns:
        Updated total accumulated cost
    """
    usage_info = cal_gemini_cost(usage_metadata, model_name)

    current_cost = usage_info['total_cost']
    total_accumulated_cost += current_cost

    output_lines = []
    output_lines.append("🌟 Usage Summary 🌟")
    output_lines.append(f"{current_stage}")
    output_lines.append(f"🛠️ Model: {usage_info['model_name']}")
    output_lines.append(f"📥 Input tokens: {usage_info['prompt_tokens']} (Cost: ${usage_info['input_cost']:.8f})")
    output_lines.append(f"📤 Output tokens: {usage_info['output_tokens']} (Cost: ${usage_info['output_cost']:.8f})")
    output_lines.append(f"💵 Current total cost: ${current_cost:.8f}")
    output_lines.append(f"🪙 Accumulated total cost so far: ${total_accumulated_cost:.8f}")
    output_lines.append("============================================\n")

    output_text = "\n".join(output_lines)
    
    print(output_text)

    with open(f"{output_dir}/cost_info.log", "a", encoding="utf-8") as f:
        f.write(output_text + "\n")
    
    return total_accumulated_cost


def aggregate_costs(cost_list: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Aggregate multiple cost dictionaries into a single summary.
    
    Args:
        cost_list: List of cost dictionaries from cal_gemini_cost()
    
    Returns:
        Aggregated cost dictionary
    """
    if not cost_list:
        return {
            'model_name': 'N/A',
            'prompt_tokens': 0,
            'input_cost': 0.0,
            'output_tokens': 0,
            'output_cost': 0.0,
            'total_tokens': 0,
            'total_cost': 0.0,
        }
    
    # Use the model name from the first entry
    model_name = cost_list[0]['model_name']
    
    total_prompt_tokens = sum(c['prompt_tokens'] for c in cost_list)
    total_output_tokens = sum(c['output_tokens'] for c in cost_list)
    total_input_cost = sum(c['input_cost'] for c in cost_list)
    total_output_cost = sum(c['output_cost'] for c in cost_list)
    
    return {
        'model_name': model_name,
        'prompt_tokens': total_prompt_tokens,
        'input_cost': total_input_cost,
        'output_tokens': total_output_tokens,
        'output_cost': total_output_cost,
        'total_tokens': total_prompt_tokens + total_output_tokens,
        'total_cost': total_input_cost + total_output_cost,
    }
