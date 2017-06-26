
package us.kbase.kbpickaxe;

import java.util.HashMap;
import java.util.Map;
import javax.annotation.Generated;
import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;


/**
 * <p>Original spec-file type: PicAxeResults</p>
 * 
 * 
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("com.googlecode.jsonschema2pojo")
@JsonPropertyOrder({
    "model_ref"
})
public class PicAxeResults {

    @JsonProperty("model_ref")
    private String modelRef;
    private Map<String, Object> additionalProperties = new HashMap<String, Object>();

    @JsonProperty("model_ref")
    public String getModelRef() {
        return modelRef;
    }

    @JsonProperty("model_ref")
    public void setModelRef(String modelRef) {
        this.modelRef = modelRef;
    }

    public PicAxeResults withModelRef(String modelRef) {
        this.modelRef = modelRef;
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
        return ((((("PicAxeResults"+" [modelRef=")+ modelRef)+", additionalProperties=")+ additionalProperties)+"]");
    }

}
