/* ************************************************************************
   Copyright: 2015 Tobias Oetiker
   License:   ???
   Authors:   Tobias Oetiker <tobi@oetiker.ch>
 *********************************************************************** */

/**
 * Main application class.
 * @asset(aze_op/*)
 */
qx.Class.define("aze_op.Application", {
    extend : callbackery.Application,
    members : {
        main : function() {
            // Call super class
            this.base(arguments);
        }
    }
});
