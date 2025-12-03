"""
Agent Modules - ReAct and Tool-Using Agents

Uses official DSPy modules for maximum compatibility and optimization.
"""
from __future__ import annotations

import dspy
from typing import Callable, Any
import json


def create_tool(name: str, description: str, func: Callable[..., str]) -> Callable:
    """
    Create a tool function compatible with dspy.ReAct.

    The official dspy.ReAct expects callable functions with docstrings.

    Usage:
        def calculate(expression: str) -> str:
            return str(eval(expression))

        calc_tool = create_tool("calculator", "Evaluate math expressions", calculate)
        agent = dspy.ReAct("question -> answer", tools=[calc_tool])
    """
    # DSPy uses the function's docstring as the tool description
    func.__doc__ = description
    func.__name__ = name
    return func


class ReActAgent:
    """
    ReAct Agent wrapper using official dspy.ReAct.

    This wraps the official DSPy ReAct module for easier use with our API.

    Official dspy.ReAct features:
    - Built-in trajectory management
    - Context window overflow handling (truncate_trajectory)
    - Async support (acall)
    - Optimized prompting from Stanford research

    Usage:
        tools = [calculator_func, search_func]  # Functions with docstrings
        agent = ReActAgent(tools=tools, max_iters=5)
        result = agent.run(question="What is 25 * 4 + 100?")
        print(result.answer)
    """

    def __init__(self, tools: list[Callable], max_iters: int = 5, signature: str = "question -> answer"):
        self.tools = tools
        self.max_iters = max_iters
        self.signature = signature
        self._react = dspy.ReAct(signature=signature, tools=tools, max_iters=max_iters)

    def run(self, question: str) -> dspy.Prediction:
        """Execute the agent and return result with trajectory info."""
        try:
            result = self._react(question=question)

            # Build trajectory from the internal state if available
            trajectory = self._extract_trajectory(result)

            return dspy.Prediction(
                answer=getattr(result, 'answer', str(result)),
                trajectory=trajectory,
                iterations=self.max_iters,  # dspy.ReAct doesn't expose actual iterations
                success=True,
            )
        except Exception as e:
            return dspy.Prediction(
                answer=f"Agent error: {str(e)}",
                trajectory=f"Error during execution: {str(e)}",
                iterations=0,
                success=False,
            )

    def _extract_trajectory(self, result) -> str:
        """Extract trajectory information from ReAct result."""
        trajectory_parts = []

        # Try to get trajectory from result attributes
        if hasattr(result, 'trajectory'):
            return result.trajectory

        # Build from observations if available
        if hasattr(result, 'observations'):
            for i, obs in enumerate(result.observations):
                trajectory_parts.append(f"Step {i+1}: {obs}")

        # Include reasoning if available
        if hasattr(result, 'reasoning'):
            trajectory_parts.insert(0, f"Reasoning: {result.reasoning}")

        if trajectory_parts:
            return "\n".join(trajectory_parts)

        return "Trajectory not available"

    async def arun(self, question: str) -> dspy.Prediction:
        """Async execution of the agent."""
        try:
            result = await self._react.acall(question=question)
            trajectory = self._extract_trajectory(result)

            return dspy.Prediction(
                answer=getattr(result, 'answer', str(result)),
                trajectory=trajectory,
                iterations=self.max_iters,
                success=True,
            )
        except Exception as e:
            return dspy.Prediction(
                answer=f"Agent error: {str(e)}",
                trajectory=f"Error during execution: {str(e)}",
                iterations=0,
                success=False,
            )


# Legacy Tool class for backward compatibility
class Tool:
    """
    Legacy tool wrapper - converts to dspy.ReAct compatible format.

    Prefer using create_tool() for new code.
    """

    def __init__(self, name: str, description: str, func: Callable[..., str]):
        self.name = name
        self.description = description
        self.func = func
        # Make it callable and dspy-compatible
        self._dspy_tool = create_tool(name, description, func)

    def execute(self, *args, **kwargs) -> str:
        """Execute the tool and return result as string"""
        try:
            result = self.func(*args, **kwargs)
            return str(result)
        except Exception as e:
            return f"Error executing {self.name}: {str(e)}"

    def to_dspy_tool(self) -> Callable:
        """Convert to dspy.ReAct compatible tool."""
        return self._dspy_tool

    def __repr__(self) -> str:
        return f"Tool({self.name}: {self.description})"


class CodeSignature(dspy.Signature):
    """Generate code to solve a problem"""

    task: str = dspy.InputField(desc="Description of what the code should do")
    language: str = dspy.InputField(desc="Programming language to use")
    code: str = dspy.OutputField(desc="The generated code")
    explanation: str = dspy.OutputField(desc="Explanation of how the code works")


class CodeAgent(dspy.Module):
    """
    Code Generation Agent

    Generates code with explanations. Can optionally execute Python code
    to verify it works.

    Usage:
        agent = CodeAgent(execute_python=True)
        result = agent(
            task="Write a function to calculate fibonacci numbers",
            language="python"
        )
        print(result.code)
        print(result.explanation)
        if result.execution_result:
            print(result.execution_result)
    """

    def __init__(self, execute_python: bool = False):
        super().__init__()
        self.execute_python = execute_python
        self.generate = dspy.ChainOfThought(CodeSignature)

    def _safe_execute(self, code: str) -> str:
        """Safely execute Python code and return output"""
        if not self.execute_python:
            return ""

        try:
            # Create a restricted namespace
            namespace = {"__builtins__": {"print": print, "range": range, "len": len}}

            # Capture output
            import io
            import sys
            old_stdout = sys.stdout
            sys.stdout = captured = io.StringIO()

            exec(code, namespace)

            sys.stdout = old_stdout
            return captured.getvalue() or "Code executed successfully (no output)"
        except Exception as e:
            return f"Execution error: {str(e)}"

    def forward(self, task: str, language: str = "python") -> dspy.Prediction:
        # Generate code
        pred = self.generate(task=task, language=language)

        result = dspy.Prediction(
            code=pred.code,
            explanation=pred.explanation,
            language=language,
        )

        # Optionally execute Python code
        if language.lower() == "python" and self.execute_python:
            result.execution_result = self._safe_execute(pred.code)

        return result


# Pre-built tools for common use cases
def create_calculator_tool() -> Callable:
    """
    Calculator tool for math expressions.

    Returns a dspy.ReAct compatible function.
    """
    def calculator(expression: str) -> str:
        """Evaluate mathematical expressions like '2 + 2' or 'sqrt(16)'. Supports +, -, *, /, ^, (), and basic math."""
        try:
            # Safe eval for math only
            allowed = set("0123456789+-*/().^ ")
            if not all(c in allowed for c in expression):
                return "Invalid expression - only numbers and math operators allowed"
            result = eval(expression.replace("^", "**"))
            return str(result)
        except Exception as e:
            return f"Error: {str(e)}"

    return calculator


def create_json_tool() -> Callable:
    """
    JSON parsing tool.

    Returns a dspy.ReAct compatible function.
    """
    def json_parser(json_str: str) -> str:
        """Parse and format JSON data. Pass a JSON string to validate and pretty-print it."""
        try:
            data = json.loads(json_str)
            return json.dumps(data, indent=2)
        except Exception as e:
            return f"Invalid JSON: {str(e)}"

    return json_parser


def create_legacy_calculator_tool() -> Tool:
    """Legacy Tool wrapper for calculator - for backward compatibility."""
    def calculate(expression: str) -> str:
        allowed = set("0123456789+-*/().^ ")
        if not all(c in allowed for c in expression):
            return "Invalid expression"
        result = eval(expression.replace("^", "**"))
        return str(result)
    return Tool("calculator", "Evaluate mathematical expressions", calculate)


def create_legacy_json_tool() -> Tool:
    """Legacy Tool wrapper for JSON parser - for backward compatibility."""
    def parse_json(json_str: str) -> str:
        data = json.loads(json_str)
        return json.dumps(data, indent=2)
    return Tool("json_parser", "Parse and format JSON data", parse_json)
