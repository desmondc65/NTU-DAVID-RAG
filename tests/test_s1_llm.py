import time
import sys
import base64
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.llm_clients.local_llm import LocalLLMClient

def main():
    print("Initializing client...")
    client = LocalLLMClient(
        model_name="qwen2.5-vl-72b-instruct",
        base_url="http://localhost:8000/v1",
        api_key="local-dev-key",
    )
    
    prompt = """# Accounting for Wealth Concentration in the United States†

By Barış Kaymak, David Leung, and Markus Poschke\*

We assess the empirical relevance of different macroeconomic modeling approaches to wealth concentration, using the joint distribution of earnings, capital income, and net worth in combination with an OLG model of household heterogeneity. We find large earnings disparities to be the primary source of US wealth concentration. This reflects the fact that labor income, from salaries but also from entrepreneurship, is a major income source for top income and wealth groups in the data. Bequests and differences in rates of return on capital together explain about half the holdings of the wealthiest of households. (JEL D31, E25, G51, J23, J31, L26 )

Net worth, the balance of a household’s assets and liabilities, is highly concen-trated in the United States, with the wealthiest 1 percent holding over one-third of total wealth. Economists have proposed a set of explanations for this, highlighting factors such as labor income heterogeneity; capital return heterogeneity; entrepreneurial activity, which combines heterogeneity in labor and capital incomes; or bequests. These explanations differ in their depictions of who the wealthy are and how they become wealthy, yielding conflicting perspectives on economic policy.1 Regrettably, a direct empirical assessment of how important labor and capital income are for building fortunes in the United States has proven elusive due to the lack of longitudinal data on finances of high-wealth households.

In this paper, we assess the relevance of different modeling approaches by exploiting their diverging predictions for the income composition of top income and wealth groups. If concentration is driven by asset return differences or bequests, these groups should rely heavily on capital income. In contrast, prominent labor income should point to earnings heterogeneity as a key driver of wealth concentration.

Data from administrative tax records show a substantial labor income component for high-income households (Piketty, Saez, and Zucman 2018). We reach a similar conclusion using data from the Survey of Consumer Finances (SCF). Earnings account for almost one-half to two-thirds of total income for the top 1 percent of incomes, depending on the treatment of capital gains and proprietors’ income. Households outside the top groups rely almost exclusively on labor income. These suggest an indispensable role for earnings in shaping the wealth distribution.

The lower labor income shares among the highest income and wealth groups nonetheless reflect the relative importance of capital income for these groups. Our analysis indicates, however, that the low shares among the wealthiest mainly reflect their larger asset stocks rather than higher returns. By contrast, we estimate sizable return differences across income groups even after accounting for their wealth.

The effect of these differences on wealth concentration depends on fluctuations in income and asset returns over a lifetime. However, cross-sectional data alone cannot reveal how such dynamics impact wealth accumulation. To discipline these dynamics, we employ a life cycle model of wealth formation calibrated to match the joint distributions of earnings, income, and wealth in the data, in contrast to common macro approaches that focus solely on marginal distributions.

The model incorporates key savings motives like precautionary behavior, retirement planning, and bequests. When combined with empirical income and wealth distributions, the calibrated model yields realistic earnings risk, variation of asset returns with income and wealth, and life cycle profiles of earnings, income, and wealth.

Conducting a series of counterfactual experiments to assess each component’s contribution to wealth concentration, we find earnings heterogeneity to be the primary driver of top wealth shares, directly explaining about half of wealth concentration on average, regardless of the presence of other mechanisms in the model.

Differences in bequests and asset returns together explain the remainder of wealth concentration. Individually, return heterogeneity mostly impacts the top 0.1 percent wealth share, while bequest inequality mostly affects the Gini coefficient of wealth. The two mechanisms amplify each other, especially in terms of their effect on the top wealth shares. The marginal effect of each is much smaller when the other mechanism is absent."""
    print("Sending request...")
    
    start_time = time.time()
    resp = client.generate_response(
        system_prompt="return title and authors only",
        user_prompt=prompt,
        response_mime_type="text/markdown",
    )
    end_time = time.time()
    
    elapsed = end_time - start_time
    # Since we can't easily get the exact token count from the simple client wrapper return string,
    # we can approximate using words or characters, assuming ~4 characters = 1 token.
    estimated_tokens = len(resp) / 4.0
    tokens_per_sec = estimated_tokens / elapsed
    
    print("\n--- Response ---")
    print(resp)
    print("----------------\n")
    print(f"Time taken: {elapsed:.2f} seconds")
    print(f"Estimated Tokens Generated: ~{int(estimated_tokens)}")
    print(f"Estimated Speed: ~{tokens_per_sec:.2f} tokens/second")
    print("\n===========================================\n")

def test_vision():
    print("Initializing vision client...")
    client = LocalLLMClient(
        model_name="qwen2.5-vl-72b-instruct",
        base_url="http://localhost:8000/v1",
        api_key="local-dev-key",
    )
    
    image_path = "/home3/davidlcs/Econ-Rag/NTU-DAVID-RAG/tests/output_pdf_extract/Manuscript/auto/images/0e27e520e29fbfa7df94a49cca74b94056a565b472257fe0d097ebcbf4bc111d.jpg"
    
    print(f"Loading image {image_path}...")
    with open(image_path, "rb") as image_file:
        base64_image = base64.b64encode(image_file.read()).decode('utf-8')
    
    content = [
        {"type": "text", "text": "Please transcribe all text and mathematical formulas visible in this image. Output in markdown format."},
        {
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{base64_image}"
            }
        }
    ]
    
    print("Sending vision request to LLM...")
    start_time = time.time()
    resp = client.generate_response(
        user_prompt=content,
        response_mime_type="text/markdown",
        max_tokens=2048,
    )
    end_time = time.time()
    
    elapsed = end_time - start_time
    
    print("\n--- Vision Response ---")
    print(resp)
    print("-----------------------\n")
    print(f"Time taken: {elapsed:.2f} seconds")

if __name__ == "__main__":
    main()
    test_vision()
