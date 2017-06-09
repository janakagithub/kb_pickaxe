/*
A KBase module: kb_picaxe
This method wraps the PicAxe tool.
*/

module kb_picaxe {
    /*
        A string representing a model id.
    */

    typedef string model_id;

    /*
        A string representing a workspace name.
    */

    typedef string workspace_name;

    typedef structure {
        string compound_id;
        string compound_name;
    }EachCompound;

    typedef structure {
        workspace_name workspace;
        model_id model_id;
        string model_ref;
        model_id out_model_id;
        list <EachCompound> compounds;
    } RunPicAxe;

    typedef structure {
        string model_ref;
    }  PicAxeResults;

    funcdef runpicaxe(RunPicAxe params) returns (PicAxeResults) authentication required;
};
