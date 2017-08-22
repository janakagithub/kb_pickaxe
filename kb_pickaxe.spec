/*
A KBase module: kb_picaxe
This method wraps the PicAxe tool.
*/

module kb_pickaxe {
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
        string rule_set;
        int generations;
        string prune;
        int add_transport;
        model_id out_model_id;
        list <EachCompound> compounds;
    } RunPickAxe;

    typedef structure {
        string model_ref;
    }  PickAxeResults;

    funcdef runpickaxe(RunPickAxe params) returns (PickAxeResults) authentication required;
};
