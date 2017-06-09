
package us.kbase.kbpicaxe;

import java.util.HashMap;
import java.util.Map;
import javax.annotation.Generated;
import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;


/**
 * <p>Original spec-file type: EachCompound</p>
 * 
 * 
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("com.googlecode.jsonschema2pojo")
@JsonPropertyOrder({
    "compound_id",
    "compound_name"
})
public class EachCompound {

    @JsonProperty("compound_id")
    private String compoundId;
    @JsonProperty("compound_name")
    private String compoundName;
    private Map<String, Object> additionalProperties = new HashMap<String, Object>();

    @JsonProperty("compound_id")
    public String getCompoundId() {
        return compoundId;
    }

    @JsonProperty("compound_id")
    public void setCompoundId(String compoundId) {
        this.compoundId = compoundId;
    }

    public EachCompound withCompoundId(String compoundId) {
        this.compoundId = compoundId;
        return this;
    }

    @JsonProperty("compound_name")
    public String getCompoundName() {
        return compoundName;
    }

    @JsonProperty("compound_name")
    public void setCompoundName(String compoundName) {
        this.compoundName = compoundName;
    }

    public EachCompound withCompoundName(String compoundName) {
        this.compoundName = compoundName;
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
        return ((((((("EachCompound"+" [compoundId=")+ compoundId)+", compoundName=")+ compoundName)+", additionalProperties=")+ additionalProperties)+"]");
    }

}
