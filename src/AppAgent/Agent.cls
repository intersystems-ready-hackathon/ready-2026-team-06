Include (%AI, %occStatus)

/// AI Hub agent that drives the AppAgent.Tools.FormBuilder toolset to build web-form
/// applications from a natural-language description. Uses OpenAI (gpt-5.5 default).
/// 
/// Provider construction: tries the IRIS Wallet / Config Store entry
///   AI.LLM.<MODELCONFIGNAME>      (default name: "OpenAI")
/// first. If that entry is not configured, falls back to the OPENAI_API_KEY
/// environment variable (same path as src/Sample/Agent.cls).
Class AppAgent.Agent Extends %AI.Agent
{

Parameter PROVIDER = "openai";

Parameter MODEL = "gpt-5.5";

Parameter TOOLSETS = "AppAgent.ToolSet";

/// Config Store entry name to look for under "AI.LLM.<name>".
/// Set to "" to skip the Config Store path entirely and use the env var only.
Parameter MODELCONFIGNAME = "OpenAI";

/// System prompt — markdown, kept stable across turns to maximize prompt-cache hits.
XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# FormBuilder Assistant

You turn natural-language descriptions into deployed web-form applications by orchestrating
the FormBuilder tools.

## Available capabilities

- **GetLanguage(Prompt)** — detect the user's language code (EN, DE, FR, …)
- **GetEmail(Prompt)** — extract an email address from a prompt (empty string if none)
- **GetAppName(Prompt)** — generate a short, sanitized, uppercase application name (≤ 40 chars)
- **GetProperties(Prompt, Language, FormName)** — generate a CSV (`~`-delimited) property list for the application
- **CreateClass(FormData, Language, Name, Prompt)** — generate the IRIS class from the property list
- **GetClassSource(ClassName)** — retrieve the XML source of a generated class
- **CreateForm(FormData, Language, Name, ClassName, Prompt, Email)** — deploy a public web form and email the link
- **CreateFormMinimal(Prompt)** — one-shot end-to-end: language + name + properties + class + form, all server-side

## How to behave

1. If the user's prompt already includes both a clear application description AND an email address,
   **prefer `CreateFormMinimal`** unless they explicitly ask for step-by-step control.
2. Otherwise run the staged pipeline in order:
   `GetLanguage` → `GetEmail` → `GetAppName` → `GetProperties` → `CreateClass` → `CreateForm`.
   Confirm each intermediate result to the user before moving on, and reuse exact names
   returned by earlier tools (do not invent or rephrase them).
3. If `GetEmail` returns an empty address, ask the user for one before calling `CreateForm`.
4. If any tool returns an `error` field in its response, surface the error verbatim and ask the user how to proceed.
5. Once a language is detected, **respond to the user in that language**.
6. Never fabricate property names, app names, or class names — always quote what the tools returned.
7. When you finish, give the user the deployed form URL clearly on its own line.
}

/// Interactive terminal REPL. Creates one session, prompts repeatedly, keeps the session
/// alive across turns. Exit with /quit or /exit. Other commands: /reset, /stats, /help.
///
///   USER> do ##class(AppAgent.Agent).RunAgent()
ClassMethod RunAgent() As %Status
{
    Set sc = $$$OK
    Try {
        Set agent = ..%New()
        $$$ThrowOnError(agent.%Init())
        Set session = agent.CreateSession()

        Write !,"=== AppAgent REPL — model=",agent.Model," provider=",agent.Provider.Name," ===",!
        Write "Type a message and press Enter. Commands: /quit /reset /stats /help",!!

        Set done = 0
        For {
            Quit:done

            Write "you> "
            Read userInput
            Write !
            Set userInput = $Get(userInput)

            If userInput = "" {
                // empty input — re-prompt
            }
            ElseIf (userInput = "/quit") {
                Set done = 1
            }
            ElseIf (userInput = "/exit") {
                Set done = 1
            }
            ElseIf (userInput = "/q") {
                Set done = 1
            }
            ElseIf (userInput = "/help") {
                Write "/quit  — exit",!
                Write "/reset — start a new session (clears history)",!
                Write "/stats — show session stats",!!
            }
            ElseIf (userInput = "/reset") {
                Set session = agent.CreateSession()
                Write "[session reset]",!!
            }
            ElseIf (userInput = "/stats") {
                Set stats = session.GetStats()
                Write "interactions: ",stats."total_interactions",!
                Write "tool calls:   ",stats."total_tool_calls",!
                Write "tokens:       ",(stats."total_prompt_tokens" + stats."total_completion_tokens"),!
                Write "ctx tokens:   ",stats."current_context_tokens"," / ",stats."model_context_size",!!
            }
            Else {
                // Normal turn
                Try {
                    Set response = agent.Chat(session, userInput)
                    Write "agent> ",response.Content,!!
                }
                Catch ex {
                    If ex.Name = "<INTERRUPT>" {
                        Write !,"[interrupted — type /quit to exit, or send another message]",!!
                    }
                    ElseIf ex.%IsA("%Exception.StatusException") {
                        Write "[error] ",$SYSTEM.Status.GetErrorText(ex.AsStatus()),!!
                    }
                    Else {
                        Write "[error] ",ex.DisplayString(),!!
                    }
                }
            }
        }

        // Goodbye summary
        Set stats = session.GetStats()
        Write !,"=== session ended ===",!
        Write "interactions: ",stats."total_interactions",!
        Write "tool calls:   ",stats."total_tool_calls",!
        Write "total tokens: ",(stats."total_prompt_tokens" + stats."total_completion_tokens"),!
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Write "[fatal] ",$SYSTEM.Status.GetErrorText(sc),!
    }
    Quit sc
}

/// Provider construction with Wallet-first / env-var fallback.
Method %CreateProvider() As %Status
{
    Set sc = $$$OK
    Try {
        // Path 1: IRIS Wallet / Config Store (preferred when configured)
        If ..#MODELCONFIGNAME '= "" {
            Set scCfg = ##class(%ConfigStore.Configuration).GetDetails(
                "AI.LLM." _ ..#MODELCONFIGNAME, .details, 0, 1)
            If $$$ISOK(scCfg), $IsObject($G(details)) {
                Set providerName = $S($G(details."model_provider")'="": details."model_provider", 1: ..#PROVIDER)
                Set ..Provider = ##class(%AI.Provider).Create(providerName, details)
                If $G(details."model") '= "" Set ..Model = details."model"
                Quit
            }
            // Config Store entry not present — fall through to env var
        }

        // Path 2: OPENAI_API_KEY environment variable
        Set apiKey = $System.Util.GetEnviron("OPENAI_API_KEY")
        If apiKey = "" {
            Set sc = $$$ERROR($$$GeneralError, "No API key found for provider '" _ ..#PROVIDER _ "'. Configure the IRIS Wallet / Config Store entry 'AI.LLM." _ ..#MODELCONFIGNAME _ "' or set the OPENAI_API_KEY environment variable.")
            Quit
        }
        Set ..Provider = ##class(%AI.Provider).Create(..#PROVIDER, {"api_key": (apiKey)})
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

}
