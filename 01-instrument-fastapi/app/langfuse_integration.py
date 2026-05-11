"""Langfuse integration for LLM tracing.

Captures LangChain LLM calls to Langfuse, enabling LLM-native observability.
"""
from __future__ import annotations

import os
from typing import Any

from langchain_core.callbacks import BaseCallbackHandler
from langfuse import Langfuse
from langfuse.decorators import observe


# Initialize Langfuse client
langfuse_client = Langfuse(
    public_key=os.getenv("LANGFUSE_PUBLIC_KEY", "pk-lf-mock"),
    secret_key=os.getenv("LANGFUSE_SECRET_KEY", "sk-lf-mock"),
    host=os.getenv("LANGFUSE_HOST", "http://langfuse:3000"),
)


class LangfuseCallbackHandler(BaseCallbackHandler):
    """LangChain callback handler that sends traces to Langfuse."""

    def __init__(self, trace_name: str = "inference"):
        super().__init__()
        self.trace_name = trace_name
        self.trace_id = None

    def on_llm_start(self, serialized: dict[str, Any], prompts: list[str], **kwargs: Any) -> str:
        """Called when LLM starts."""
        trace = langfuse_client.trace(name=self.trace_name)
        self.trace_id = trace.id
        langfuse_client.generation(
            name="llm_call",
            input={"prompts": prompts},
            model=serialized.get("id", ["unknown"])[-1],
            trace_id=self.trace_id,
        )
        return self.trace_id

    def on_llm_end(self, response: Any, **kwargs: Any) -> None:
        """Called when LLM ends."""
        if hasattr(response, "generations"):
            output = {
                "generations": [
                    [{"text": g.text, "finish_reason": g.generation_info.get("finish_reason")}
                     for g in gens]
                    for gens in response.generations
                ]
            }
        else:
            output = str(response)

        if self.trace_id:
            langfuse_client.generation(
                name="llm_result",
                output=output,
                trace_id=self.trace_id,
            )

    def on_llm_error(self, error: Exception | KeyboardInterrupt, **kwargs: Any) -> None:
        """Called when LLM errors."""
        if self.trace_id:
            langfuse_client.generation(
                name="llm_error",
                output={"error": str(error)},
                trace_id=self.trace_id,
            )


@observe()
def trace_inference(prompt: str, model: str) -> dict[str, Any]:
    """Wrapper to trace a single inference request to Langfuse."""
    return {
        "model": model,
        "prompt": prompt,
        "status": "ok",
    }


def get_langfuse_callback() -> LangfuseCallbackHandler:
    """Get a Langfuse callback handler for use in LangChain chains."""
    return LangfuseCallbackHandler()
