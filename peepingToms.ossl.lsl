/*
 * Peeping Toms
 * Version: 1.3.1
 *
 * Place this script inside a poseball or an animated object. When a real avatar
 * sits on it, NPCs around will come and watch.
 *
 * DO NOT ALTER THE SCRIPT. It will self-update when a new version is available
 * and any change will be lost. Use object desc to set your parameters.
 * Do disable self-updates, set scrupAllowUpdates to FALSE or remove the version
 * number from the script name.
 *
 * This script is designed to work with NPCs made by "OSW NPC" or "ActiveNPCs"
 *
 * You can set preferences in object description to avoid modifying the script.
 * Use coma separator, in the form:
 *    searchRadius, minRadius, maxRadius, spreading, orientation, changeDress
 *
 * No need to fill all of them, you can set only the 3 first for example:
 *    40, 3.50, 5.5
 * will scan on 40 meters and position the NPCs between 3.50 and 5 meters
 *
 * Empty values will  be ignored:
 *    40,,,,, Formal
 * will scan 40 meters, use "Formal" dress and keep other default values
 *
 */

float searchRadius = 20; // catch NPCs within this distance (in meters)
float minRadius = 1.5;   // peeper assigned position minimum distance
float maxRadius = 2.5;   // peeper assigned position maximum distance
float spreading = 360;   // available angle for distribution, 360 is all around
float orientation = 0;   // adjust orientation when spreading is < 360
string changeDress = "";
    // if changeDress is set, NPC will put this outfit when watching
    // make sure APP_npcname_outfit exist for all

float scanInterval = 5;   //seconds
integer npcControllerChannel = 68; // Your NPC rezzer channel, shoulld be 68

// The following will be calculated during script run, change is useless
float firstAngle;
float deltaAngle;
key victim;
vector victimPos;

list peepers;
list peepersNames;
list peepersPos;
list innerCircle;
list newBies;
list workers;
string currentState;
float errorMargin;

// Change only in your master script
string scrupURL = "https://speculoos.world/scrup/scrup.php"; // Change to your scrup.php URL
integer scrupPin = 56748; // Change or not, it shouldn't hurt
integer scrupAllowUpdates = TRUE; // should always be true, except for debug
string scrupRequestID; // will be set while running
string version; // will be set while running

debug (string message) {
    // llOwnerSay("/me (" + currentState + "): " + message);
}

scrup() {
    debug("starting scrup");
    string scrupVersion = "1.0";
    if(!scrupAllowUpdates)  {
        debug("updates not allowed");
        llSetRemoteScriptAccessPin(0);
        return;
    }

    // Get version from script name
    string name = llGetScriptName();
    string part;
    // list softParts=[];
    list parts=llParseString2List(name, [" "], "");
    integer i; for (i=1;i<llGetListLength(parts);i++)
    {
        part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], ""), 0);
        if(llGetListLength(llParseString2List(main, ["."], [])) > 1
        && llGetListLength(llParseString2List(main, [".", 0,1,2,3,4,5,6,7,8,9], [])) == 0) {
            version = part;
            jump break;
        }
    }
    debug(name + " has no version, disabling scrup");
    version = "";
    scrupAllowUpdates = FALSE;
    llSetRemoteScriptAccessPin(0);
    return;

    @break;
    list scriptInfo = [ llDumpList2String(llList2List(parts, 0, i - 1), " "), version ];
    string scriptname = llList2String(scriptInfo, 0);
    version = llList2String(scriptInfo, 1);

    llOwnerSay(scriptname + " version " + version);

    if(llGetStartParameter() == scrupPin) {
        // Delete other scripts with the same name. As we just got started after
        // an update, we should be the newest one.
        i=0; do {
            string found = llGetInventoryName(INVENTORY_SCRIPT, i);
            if(found != llGetScriptName()) {
                // debug("what shall we do with " + found);
                integer match = llSubStringIndex(found, scriptname + " ");
                if(match == 0) {
                    llOwnerSay("deleting duplicate '" + found + "'");
                    llRemoveInventory(found);
                }
            }
        } while (i++ < llGetInventoryNumber(INVENTORY_SCRIPT)-1);
    }

    list params = [ "loginURI=" + osGetGridLoginURI(), "action=register",
    "type=client", "scriptname=" + scriptname, "pin=" + scrupPin,
    "version=" + version, "scrupVersion=" + scrupVersion ];
    scrupRequestID = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));
    llSetRemoteScriptAccessPin(scrupPin);
}

npcCommand(string name, string command) {
    llRegionSay(npcControllerChannel, "! " + llGetOwner() + " " + name + " " + name + " " + command);
}

string name2FirstName(string name) {
    return llGetSubString(name, 0,llSubStringIndex(name, " ")-1);
}
string key2FirstName(key agent) {
    string name = llKey2Name(agent);
    return name2FirstName(name);
}

checkSittingBulls() {
    integer i=llGetNumberOfPrims();
    integer l=llGetObjectPrimCount(llGetKey());

    workers = [];
    key found = NULL_KEY;
    while (i>l)
    {
        key who=llGetLinkKey(i);
        if (osIsNpc(who)) workers += who;
        else {
            found = who;
            debug("found " + llKey2Name(found) + " on " + i+"/"+l);
        }
        i--;
    }
    if (found == NULL_KEY) {
        debug("nobody to follow");
        victim = NULL_KEY;
        if(currentState != "default") state default;
    }
    else {
        victim = found;
        if(currentState != "peeping") state peeping;
    }
}

vector getNewPeeperPos(integer i, vector currentVictimPos) {
    float distance = minRadius + llFrand(maxRadius - minRadius);
    float agentAngle = firstAngle - (i + 1) * deltaAngle;
    rotation relRot = llGetRot() * llEuler2Rot(<0,0,agentAngle>*DEG_TO_RAD);
    vector relPos = <distance,0,0> * relRot;
    vector peeperPos = currentVictimPos + relPos;
    return peeperPos;
}

float getDistanceFrom(vector target, key agent) {
    list details = llGetObjectDetails(agent, [OBJECT_POS]);
    vector pos = llList2Vector(details, 0);
    float distance = llVecDist(pos, target );
    return distance;
}

default
{
    state_entry()
    {
        scrup();
        currentState = "default";
        debug("reading preferences");

        list prefs = llParseStringKeepNulls(llGetObjectDesc(), ",", "");
        integer prefsCount = llGetListLength(prefs);
        if(prefsCount > 0 && llList2String(prefs, 0)!="") searchRadius = llList2Float(prefs, 0);
        if(prefsCount > 1 && llList2String(prefs, 1)!="") minRadius = llList2Float(prefs, 1);
        if(prefsCount > 2 && llList2String(prefs, 2)!="") maxRadius = llList2Float(prefs, 2);
        if(prefsCount > 3 && llList2String(prefs, 3)!="") spreading = llList2Float(prefs, 3);
        if(prefsCount > 4 && llList2String(prefs, 4)!="") orientation = llList2Float(prefs, 4);
        if(prefsCount > 5 && llList2String(prefs, 5)!="") changeDress = llList2String(prefs, 5);

        debug("prefs:\n"
        + "searchRadius: " + (string)searchRadius + "\n"
        + "minRadius: " + (string)minRadius + "\n"
        + "maxRadius: " + (string)maxRadius + "\n"
        + "spreading: " + (string)spreading + "\n"
        + "orientation: " + (string)orientation + "\n"
        + "changeDress: " + (string)changeDress + "\n"
        );
        errorMargin = (maxRadius - minRadius) / 2;
        // if(scanInterval < searchRadius) scanInterval = searchRadius;

        checkSittingBulls();
        integer i= 0;
        do {
            string name = llList2String(peepersNames, i);
            npcCommand(name, "leave");
            if(changeDress!="")
            npcCommand(name, "dress");
            i++;
        } while (i < llGetListLength(peepersNames));
        peepers = [];
        peepersNames = [];
        innerCircle = [];
    }

    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            debug("links changed in " + currentState);
            checkSittingBulls();

        }
    }

    on_rez(integer start_param)
    {
        scrup();
    }
}

state peeping
{
    state_entry()
    {
        llSetRemoteScriptAccessPin(0); // We don't want update when using it

        currentState = "peeping";
        debug("I'll be watching you, " + llKey2Name(victim));
        llSetTimerEvent(scanInterval);
    }

    timer()
    {
        llSensor("", "", AGENT | NPC, searchRadius, PI);
    }

    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            debug("links changed in " + currentState);
            checkSittingBulls();
        }
    }

    sensor(integer num)
    {
        list currentPeepers = [];
        list newPeepers = peepers;
        peepers = [];
        peepersNames = [];
        integer hasChanges = FALSE;

        integer i = 0; do {
            key agent = llDetectedKey(i);
            if(osIsNpc(agent))
            {
                if (llListFindList(workers, agent) < 0) {
                    currentPeepers += agent;
                    if(llListFindList(newPeepers, agent) < 0) {
                        newPeepers += agent;
                        hasChanges = TRUE;
                    }
                }
            }
        } while (i++ < num-1);

        if(llGetListLength(newPeepers) > 0) {
            i=0; do {
                key agent=llList2Key(newPeepers, i);
                if(llListFindList(currentPeepers, agent) >= 0) {
                    peepers += agent;
                    peepersNames += key2FirstName(agent);
                }
                else {
                    hasChanges = TRUE;
                }
            } while (i++ < llGetListLength(newPeepers)-1);
        }

        list details = llGetObjectDetails(victim, [OBJECT_POS]);
        vector currentVictimPos = llList2Vector(details, 0);
        float victimDistanceFromPrevious = llVecDist(currentVictimPos, victimPos );
        if(victimDistanceFromPrevious < 0.2) {
            currentVictimPos = victimPos;
        } else {
            victimPos = currentVictimPos;
            hasChanges = TRUE;
        }
        // if(victimPos != currentVictimPos) hasChanges = TRUE;

        vector peeperPos;
        string peeperPosStr;

        if(hasChanges) {
            integer count = llGetListLength(peepers);
            if(count <= 1) {
                deltaAngle = 0;
                firstAngle = orientation;
            } else if(0 < spreading && spreading < 360) {
                deltaAngle = spreading / (count - 1);
                firstAngle = orientation + spreading / 2 + deltaAngle;
            } else {
                spreading = 360;
                deltaAngle = spreading / count ;
                firstAngle = orientation + spreading / 2 + deltaAngle;
            }
            debug("count " + (string)count);
            debug("delta " + (string)deltaAngle);
            debug("firstAngle " + (string)firstAngle);

            i=0; do {
                key agent = llList2Key(peepers, i);
                key name =  llList2Key(peepersNames, i);

                peeperPos = getNewPeeperPos(i, currentVictimPos);
                peeperPosStr = "<" + peeperPos.x + "," + peeperPos.y + "," + peeperPos.z + ">";

                if ( getDistanceFrom(currentVictimPos, agent) <= maxRadius) {
                    if ( getDistanceFrom(peeperPos, agent) >= errorMargin) {
                        npcCommand(name, "movetov " + peeperPosStr);
                    } else {
                        npcCommand(name, "lookat me");
                    }
                    // npcCommand(name, "stop");
                } else {
                    // npcCommand(name, "follow me");
                    npcCommand(name, "movetov " + peeperPosStr);
                    npcCommand(name, "lookat me");
                }
            } while (i++ < count-1);
        } else {
            i= 0;
            do {
                key agent = llList2Key(peepers, i);
                string name = llList2String(peepersNames, i);
                if(llListFindList(innerCircle, name) < 0) {
                    peeperPos = getNewPeeperPos(i, currentVictimPos);
                    peeperPosStr = "<" + peeperPos.x + "," + peeperPos.y + "," + peeperPos.z + ">";

                    if ( getDistanceFrom(currentVictimPos, agent) <= maxRadius) {
                        if ( getDistanceFrom(peeperPos, agent) >= errorMargin) {
                            npcCommand(name, "stop");
                            npcCommand(name, "movetov " + peeperPosStr);
                            npcCommand(name, "lookat me");
                        } else {
                            npcCommand(name, "lookat me");
                            if(changeDress!="")
                            npcCommand(name, "dress " + changeDress);
                            innerCircle += name;
                        }
                    }
                } else {
                    npcCommand(name, "lookat me");
                }
                i++;
            } while (i < llGetListLength(peepersNames));
        }
        // else
        // {
        //     npcCommand(name, "lookat me");
        //     // npcCommand(name, "dress " + changeDress);
        // }
    }
}
