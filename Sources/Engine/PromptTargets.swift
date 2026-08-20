import Foundation

// Destination-specific conventions, folded in only on top of built-in
// Enhance where they are coherent.

extension Prompts {
    // MARK: - Target environments
    //
    // Appended to the Enhance prompt so the produced prompt matches the
    // conventions of wherever it will be pasted. Generic has no fragment.
    //
    // Every fragment asks the model to be specific, and the input frequently
    // supplies none of the specifics asked for. A bullet phrased as a flat
    // demand ("name the command that must pass") is read as a requirement to
    // satisfy, so a small model satisfies it by making something up. Measured
    // against qwen3:8b at the app's own temperature of 0.3, on an input that
    // named no path, no language, and no tooling, the Cursor fragment invented
    // one in 15 of 25 runs — "Apply changes directly to the markdown files in
    // the `docs/` directory. Run `npm run build` to confirm the build passes",
    // and on other runs a Python toolchain. The project had no docs/ directory,
    // no npm, and no Python.
    //
    // A fabricated path is worse than an omitted one: pasted into an agent, it
    // sends it chasing a directory that does not exist. So each demand for a
    // specific is now conditional on the input actually carrying it.
    //
    // Ablated over 8 runs per cell on that same input, counting runs with no
    // invented path, tool, or language:
    //
    //     old wording, no rule   4/8    <- the reported bug
    //     old wording + rule     7/8
    //     new wording, no rule   8/8
    //     new wording + rule     8/8
    //
    // The conditional wording is what fixes it; a standing rule fighting a flat
    // demand still loses sometimes. The rule is kept anyway, and applied by
    // `composeWithTarget` rather than written into the fragments, because 7/8
    // versus 4/8 is the protection a custom target gets — those have no
    // conditional wording and nobody will measure them.

    static let targetCursor = """
    - Cursor is an agentic coding IDE working inside a real repository. Write a work order for a coding agent, not a question for a chatbot.
    - Match the size of the input. A one-line question becomes a short work order in a few sentences, not a five-section spec and not a repo-wide investigation.
    - Open with the outcome in one line: what must be true of the codebase when the agent is done.
    - Name the code surface only as precisely as the input does. If the input gives file paths, directory globs, or type and function names, carry them through exactly; if it does not, do not invent a hunt ("find the module that handles X") unless the author already described a coding task with a missing location.
    - Carry through whatever stack facts the input states — language and version, framework, package manager, build or test command — and pass over in silence every one it does not. Do not derive the stack from the subject matter: a task about markdown files implies nothing about the language or tooling of the project holding them.
    - Set scope limits the input supports: which files may change, what must not be touched, whether tests, migrations, or docs are in scope. Say nothing about files the input never mentions.
    - Require verification only when the input is a change to the codebase: name the exact command when the input names one, otherwise require that the project's own build and test commands pass, leaving the agent to discover what they are. Do not add verification to a question that only asks why something happened.
    - Ask for edits to be applied directly to files, with at most a few lines of summary, only when the input asks for a change.
    """

    // A second kind of invention: writing the answer instead of asking for it.
    //
    // Both fragments below used to demand a worked example whenever the format
    // was not obvious. For a task that asks the reader to *produce* something —
    // names, taglines, subject lines, ideas — an example of the output is the
    // output, so satisfying that demand means doing the job and freezing a guess
    // into the prompt. Reported from the Claude target on "For project Prompt
    // Lens i want to rewrite its name and logo. =suggest some name and logo
    // ideas": the result carried an <examples> block containing FocusPulse,
    // PhraseCraft and QueryForge with logo descriptions, none of them the user's,
    // and grew the prompt by 244 tokens. Pasted into Claude it anchors the model
    // to three names the user never chose.
    //
    // Replaying the exact system prompt the history log recorded for that run
    // reproduces it in 12 of 12 runs; removing every mention of examples and the
    // <examples> tag, and asking for the *shape* of the answer instead of a
    // specimen of it, is clean in 12 of 12. Naming the tag was itself most of the
    // invitation — a version that kept `<examples>` while forbidding invented
    // content still leaked in 4 of 6.
    //
    // Controls: an input that supplies its own examples still carries them
    // through (5 of 5), so the useful case survives.
    //
    // ChatGPT gets the same bullet on structural, not measured, grounds. Its
    // fragment never named the <examples> tag, and under the same probe it is
    // clean 6 of 6 on the reported input and 6 of 6 on the condition its old
    // bullet actually named — a generative task with an unusual output format
    // ("taglines as a table with tone and a 1-5 punchiness score"). The demand
    // was nevertheless the same demand, and the replacement measures identically,
    // so the cautious wording is kept rather than left to be reported later.
    //
    // Recorded because an earlier pass predicted this exact failure, tested it
    // with a data-*extraction* input ("pull the key fields out of the invoices i
    // get emailed every month"), saw 4 of 4 clean, and reverted the fix. The task
    // has to be generative for the temptation to exist; an extraction prompt has
    // nothing to invent. Choose the probe to match the failure, not the feature.

    static let targetChatGPT = """
    - The prompt goes to ChatGPT in a chat window with no repository or file access, so inline any data the model needs.
    - Lead with one sentence naming the role and the objective, then context, then the task.
    - Structure it with short markdown-headed sections: Context, Task, Constraints, Output format.
    - Pin the output shape exactly: format (prose, bullets, table, JSON), approximate length, and the audience or reading level.
    - Say what to leave out as well as what to include: no preamble, no restating the question, no closing offer to help further.
    - Describe the shape of the answer you want. Do not write a specimen of it: for a task that asks for names, taglines, copy, or ideas, a specimen is the answer, and supplying one does the work you are asking for and anchors the reader to your guess.
    """

    /// No XML tags, despite Anthropic recommending them for Claude prompts.
    ///
    /// This fragment used to say "delimit distinct inputs with XML tags —
    /// <context>, <document>, <task>". That is good advice for a prompt you are
    /// composing in a document, and wrong for this app: the result goes back
    /// through **Replace**, straight into the field the text was selected from.
    /// A `<context>…</context><task>…</task>` skeleton wrapped around someone's
    /// sentence is not something they can paste over their own words, which is
    /// exactly how it was reported — "I should be getting only text which I can
    /// replace".
    ///
    /// Measured on the reported input, replaying the recorded system prompt: the
    /// tagged wording produced markup in 6 of 6 runs, this wording in 0 of 6.
    /// The historical rate across all Claude-target runs was only 18%, so the
    /// trigger is input shape — a request carrying many separate instructions
    /// invites the model to file them into sections. That is precisely the input
    /// someone reaches for Enhance with.
    ///
    /// `PanelEngine.strippedScaffolding` is the backstop, because a prompt
    /// instruction is a probability and Replace writes into a real document.
    static let targetClaude = """
    - The prompt goes to Claude, which follows long, precise prose instructions especially well.
    - Put stable context first and the actual instruction last; Claude weights the final instruction most heavily.
    - Write it as prose a person could have typed. Use no tags, no angle brackets, and no markup scaffolding: the result is pasted straight back into whatever the user was writing in, so a wrapper around their words is not something they can use. Separate context from the instruction with a sentence or a short labelled line instead.
    - Prefer explicit positive instructions over prohibitions, and state why a constraint matters; Claude generalizes correctly from the rationale.
    - Describe the shape of the answer you want. Do not write a specimen of it: for a task that asks for names, taglines, copy, or ideas, a specimen is the answer, and supplying one does the work you are asking for and anchors the reader to your guess.
    - Say plainly what the output should be, so the result is easy to use as it arrives.
    - Where accuracy matters, explicitly permit Claude to say the information is missing instead of guessing.
    """

    static let targetKimi = """
    - The prompt goes to Kimi (Moonshot), a long-context assistant often used bilingually in Chinese and English and strong at document extraction.
    - Keep the wording plain and literal. Avoid idiom, wordplay, and culture-specific references that translate badly.
    - Number the requirements, one sentence each, with the most important as step 1.
    - If long documents are supplied, say which parts to read, what to extract, and require a quoted source span for every claim.
    - State the output language explicitly (match the input language unless the task says otherwise).
    - Define the output format concretely: a numbered list, a table with named columns, or strict JSON with named keys.
    - Ask for the answer only, with no restatement of the instructions.
    """

    /// Backs every target fragment, including user-written ones.
    ///
    /// Not sufficient on its own — see the ablation above, where it left the old
    /// Cursor wording at 7/8 — so it is a floor, not the fix. It earns its place
    /// on custom targets, which ask for specifics with no conditional wording to
    /// temper them.
    ///
    /// Placed after the fragment rather than before it: this has to win against
    /// the bullets it qualifies, and the tail of a prompt is where a small model
    /// holds an instruction best. Opens by referring back to "those conventions"
    /// so it reads as governing them, and names the concrete consequence, which
    /// this codebase has found repeatedly to hold better than a bare prohibition.
    static let targetInventionRule = """
    Whatever those conventions ask for, invent no facts to satisfy them. Use only the paths, directory names, file names, commands, languages, frameworks, versions, data, and proper nouns the input actually states. Where the input states none, do not supply a plausible-looking value: no example path, no assumed package manager, no guessed build command, no stand-in data, and no investigation checklist (logs, tests, file hunts, reproduction steps) the author did not ask for. Leave the missing detail out, or say it is missing. Satisfying a convention above only partly is correct; fabricating a process or a file to satisfy it fully is not.
    """

    /// A target describes where a *prompt* is going, so it applies only to
    /// prompt authoring. Grammar fixes have no destination conventions, and
    /// tone rewrites are aimed at people rather than models.
    ///
    /// `usesBuiltInPrompt` is the load-bearing part. A target fragment is
    /// written to extend the built-in Enhance prompt and assumes its job:
    /// "write a work order for a coding agent, reference file paths, name the
    /// command that must pass". Appended to a prompt that says the opposite —
    /// the legacy custom skill prompt ended "never expand the text; if the text
    /// is already at its best, return it unchanged" — it produces one system
    /// prompt containing two contradictory jobs, and an 8B model splits the
    /// difference into something that is neither. So the fragment is added only
    /// when the prompt it extends is the one it was written for.
}
