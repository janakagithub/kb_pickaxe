
package us.kbase.kbpickaxe;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.Generated;
import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;


/**
 * <p>Original spec-file type: RunPickAxe</p>
 * 
 * 
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("com.googlecode.jsonschema2pojo")
@JsonPropertyOrder({
    "workspace",
    "model_id",
    "model_ref",
    "rule_set",
    "generations",
    "out_model_id",
    "compounds"
})
public class RunPickAxe {

    @JsonProperty("workspace")
    private String workspace;
    @JsonProperty("model_id")
    private String modelId;
    @JsonProperty("model_ref")
    private String modelRef;
    @JsonProperty("rule_set")
    private String ruleSet;
    @JsonProperty("generations")
    private Long generations;
    @JsonProperty("out_model_id")
    private String outModelId;
    @JsonProperty("compounds")
    private List<EachCompound> compounds;
    private Map<String, Object> additionalProperties = new HashMap<String, Object>();

    @JsonProperty("workspace")
    public String getWorkspace() {
        return workspace;
    }

    @JsonProperty("workspace")
    public void setWorkspace(String workspace) {
        this.workspace = workspace;
    }

    public RunPickAxe withWorkspace(String workspace) {
        this.workspace = workspace;
        return this;
    }

    @JsonProperty("model_id")
    public String getModelId() {
        return modelId;
    }

    @JsonProperty("model_id")
    public void setModelId(String modelId) {
        this.modelId = modelId;
    }

    public RunPickAxe withModelId(String modelId) {
        this.modelId = modelId;
        return this;
    }

    @JsonProperty("model_ref")
    public String getModelRef() {
        return modelRef;
    }

    @JsonProperty("model_ref")
    public void setModelRef(String modelRef) {
        this.modelRef = modelRef;
    }

    public RunPickAxe withModelRef(String modelRef) {
        this.modelRef = modelRef;
        return this;
    }

    @JsonProperty("rule_set")
    public String getRuleSet() {
        return ruleSet;
    }

    @JsonProperty("rule_set")
    public void setRuleSet(String ruleSet) {
        this.ruleSet = ruleSet;
    }

    public RunPickAxe withRuleSet(String ruleSet) {
        this.ruleSet = ruleSet;
        return this;
    }

    @JsonProperty("generations")
    public Long getGenerations() {
        return generations;
    }

    @JsonProperty("generations")
    public void setGenerations(Long generations) {
        this.generations = generations;
    }

    public RunPickAxe withGenerations(Long generations) {
        this.generations = generations;
        return this;
    }

    @JsonProperty("out_model_id")
    public String getOutModelId() {
        return outModelId;
    }

    @JsonProperty("out_model_id")
    public void setOutModelId(String outModelId) {
        this.outModelId = outModelId;
    }

    public RunPickAxe withOutModelId(String outModelId) {
        this.outModelId = outModelId;
        return this;
    }

    @JsonProperty("compounds")
    public List<EachCompound> getCompounds() {
        return compounds;
    }

    @JsonProperty("compounds")
    public void setCompounds(List<EachCompound> compounds) {
        this.compounds = compounds;
    }

    public RunPickAxe withCompounds(List<EachCompound> compounds) {
        this.compounds = compounds;
        return this;
    }

    @JsonAnyGetter
    public Map<String, Object> getAdditionalProperties() {
        return this.additionalProperties;
    }

    @JsonAnySetter
    public void setAdditionalProperties(String name, Object value) {
        this.additionalProperties.put(name, value);
    }

    @Override
    public String toString() {
        return ((((((((((((((((("RunPickAxe"+" [workspace=")+ workspace)+", modelId=")+ modelId)+", modelRef=")+ modelRef)+", ruleSet=")+ ruleSet)+", generations=")+ generations)+", outModelId=")+ outModelId)+", compounds=")+ compounds)+", additionalProperties=")+ additionalProperties)+"]");
    }

}
