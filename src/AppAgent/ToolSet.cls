Include %AI

/// Toolset bundling AppAgent.Tools.FormBuilder for the FormBuilder agent.
Class AppAgent.ToolSet Extends %AI.ToolSet [ DependsOn = AppAgent.Tools.FormBuilder ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="FormBuilderTools">
    <Description>Tools for building web-form applications via the qwiki.agimero.com REST service. Supports language detection, email extraction, app naming, property-list generation, IRIS class generation, retrieval of generated class source, deployment of a public web form, and a one-shot end-to-end form-creation tool.</Description>
    <Include Class="AppAgent.Tools.FormBuilder"/>
</ToolSet>
}

}
