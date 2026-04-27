Include (%AI, %occStatus)

/// Tools for building form applications via the qwiki.agimero.com REST API.
/// Orchestrates language detection, property extraction, class generation, and form creation.
Class AppAgent.Tools.FormBuilder Extends %AI.Tool
{

/// Detect the language of a user prompt
/// Returns the detected language code e.g. EN, DE, FR
ClassMethod GetLanguage(
	Prompt As %String(DESCRIPTION = "The user's input text")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set json.Prompt = Prompt
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/AIGetLanguage", json)
}

/// Extract an email address from a user prompt
/// Returns the email address found in the text, or empty string if none present
ClassMethod GetEmail(
	Prompt As %String(DESCRIPTION = "The user's input text")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set json.Prompt = Prompt
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/AIGetEmail", json)
}

/// Generate a short application name from a user prompt (max 40 characters)
/// Returns a concise sanitized uppercase name suitable for use as a program identifier
ClassMethod GetAppName(
	Prompt As %String(DESCRIPTION = "The user's input text describing the application")) As %DynamicObject
{
	Set text = "I would like to create software for data collection. I need a short name for the program, maximum 40 characters. "
	Set text = text _ "Please answer only and exclusively a short name. no * or comment or suggestion. "
	Set text = text _ "Topic of the program is: " _ Prompt _ " "

	Set json = ##class(%Library.DynamicObject).%New()
	Set json.Prompt = $ZCONVERT(text, "O", "UTF8")
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/AIGetAnswer", json)
}

/// Generate a pipe-delimited CSV list of properties for a new application
/// Each property row uses ~ as delimiter: Name~Type~Length~PrimaryKey~Mandatory~Description~Samples~HelpText
ClassMethod GetProperties(
	Prompt As %String(DESCRIPTION = "The user's input text describing the application"),
	Language As %String(DESCRIPTION = "Language code e.g. EN, DE, FR"),
	FormName As %String(DESCRIPTION = "Short name for the form returned by GetAppName")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set json.FormName = ..SanitizeName(FormName)
	Set json.FormPrompt = Prompt
	Set json.FormType = 1
	Set json.FormLanguage = Language
	Quit ..CallEndpoint("/iris/wwwrest/demo/AIGetProperties", json)
}

/// Generate an IRIS class from a CSV property list
/// Returns the generated class name e.g. User.ROOMDATA.cls
ClassMethod CreateClass(
	FormData As %String(DESCRIPTION = "CSV property data returned by GetProperties"),
	Language As %String(DESCRIPTION = "Language code e.g. EN"),
	Name As %String(DESCRIPTION = "Short name for the class returned by GetAppName"),
	Prompt As %String(DESCRIPTION = "Original user description of the application")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set name = ..SanitizeName(Name)
	Set json.ClassName = name
	Set json.ClassHeader = name
	Set json.ClassPrompt = $ZCONVERT(Prompt, "O", "UTF8")
	Set json.ClassLanguage = Language
	Set json.ClassRenew = 1
	Set json.ClassData = $ZCONVERT(FormData, "O", "UTF8")
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/AICreateClass", json)
}

/// Retrieve the ObjectScript source XML of a generated class
/// Returns the class definition as an XML export string
ClassMethod GetClassSource(
	ClassName As %String(DESCRIPTION = "Class name returned by CreateClass e.g. User.ROOMDATA.cls")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set json.Class = ClassName
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/GetClass", json)
}

/// Generate a web form application from a class and return the public URL
/// Returns the link to the newly created form application which is also emailed to the recipient
ClassMethod CreateForm(
	FormData As %String(DESCRIPTION = "CSV property data returned by GetProperties"),
	Language As %String(DESCRIPTION = "Language code e.g. EN"),
	Name As %String(DESCRIPTION = "Short uppercase form name e.g. ROOMDATA"),
	ClassName As %String(DESCRIPTION = "Class name returned by CreateClass e.g. User.ROOMDATA.cls"),
	Prompt As %String(DESCRIPTION = "Original user description of the application"),
	Email As %String(DESCRIPTION = "Email address to send the application link to")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set json.FormName = Name
	Set json.FormClass = ClassName
	Set json.FormHeader = "Edit " _ Name
	Set json.FormPrompt = Prompt
	Set json.FormType = 1
	Set json.FormLanguage = Language
	Set json.FormRenew = 1
	Set json.FormVersion = 0
	Set json.FormMenu = ""
	Set json.FormPublic = 1
	Set json.FormEmail = Email
	Set json.FormData = FormData
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/AICreateForm", json)
}

/// Build a complete form application from a single prompt in one call
/// The external service handles language detection, naming, and class generation automatically
/// Returns the public URL of the generated application
ClassMethod CreateFormMinimal(
	Prompt As %String(DESCRIPTION = "Full user description including email address to receive the link")) As %DynamicObject
{
	Set json = ##class(%Library.DynamicObject).%New()
	Set json.FormName = ""
	Set json.FormClass = ""
	Set json.FormHeader = ""
	Set json.FormPrompt = $ZCONVERT(Prompt, "O", "UTF8")
	Set json.FormType = ""
	Set json.FormLanguage = ""
	Set json.FormRenew = ""
	Set json.FormVersion = ""
	Set json.FormMenu = ""
	Set json.FormPublic = ""
	Set json.FormEmail = ""
	Set json.FormData = ""
	Do json.%Set("stream", 0, "boolean")
	Quit ..CallEndpoint("/iris/wwwrest/demo/AICreateForm", json)
}

ClassMethod SanitizeName(Name As %String) As %String [ Private ]
{
	Set name = $ZCONVERT($GET(Name), "U")
	Set name = $TRANSLATE(name, " .-;:_#'+*´`=){[]}(/\&%$§!" _ """")
	Set name = $EXTRACT(name, 1, 25)
	Quit name
}

ClassMethod CallEndpoint(Location As %String, RequestBody As %DynamicObject) As %DynamicObject [ Private ]
{
	Set req = ##class(%Net.HttpRequest).%New()
	Set req.Server = "qwiki.agimero.com"
	Set req.Location = Location
	Set req.Timeout = 300
	Do req.SetHeader("Content-Type", "application/json")
	Do req.EntityBody.Write(RequestBody.%ToJSON())

	Set sc = req.Post()
	If $$$ISERR(sc) {
		Quit {"error": ($SYSTEM.Status.GetErrorText(sc))}
	}

	Set raw = ""
	While req.HttpResponse.Data.AtEnd = 0 {
		Set raw = raw _ req.HttpResponse.Data.Read(3200000)
	}

	Try {
		Quit ##class(%Library.DynamicObject).%FromJSON(raw)
	} Catch {
		Quit {"data": (raw)}
	}
}

}
