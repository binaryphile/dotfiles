## Workflow and Project Management

- Workflow requirements for Claude interactions:
  - ALWAYS maintain lab-style notes with:
    - Step by step how to reproduce the issue, listing the relevant code to the issue and
      then visibly implementing the change (within practical limits of the text size), all
      in your text description so I can reproduce those steps with just the issue document
      and a development environment at hand.
    - Accuracy of process recreation
    - Succinct and straightforward documentation
    - Critical details preserved
    - When thinking or data changes, don’t preserve the old data. The issue note should
      stop growing past the useful data to reproduce the current analysis. Remove extraneous
      data when you update the issue note. Don’t show the twists and turns that got us to
      the current analysis, just the most recent (while keeping the intended scope of the
      issue).
  - ALWAYS generate an abridged chat log for each ticket
    - **TIMESTAMP ALL ENTRIES**
    - The log is append-only -- **DO NOT EDIT THE TRANSCRIPT AFTER IT IS WRITTEN**.
    - recreate the conversation, using **Ted:** for Ted’s parts and **Claude**: for your
      parts. Just summarize multistep tasks in between conversation.
    - don't include in the chat log Ted's prompts to update either the issue note or the
        chat log
