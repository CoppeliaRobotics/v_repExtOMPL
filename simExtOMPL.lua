local simOMPL={}

--@fun setGoalStates set multiple goal states at once, equivalent to calling simOMPL.setGoalState, simOMPL.addGoalState, simOMPL.addGoalState...
--@arg int taskHandle the handle of the task
--@arg table states a table of tables, one element for each goal state
function simOMPL.setGoalStates(taskHandle,states)
    simOMPL.setGoalState(taskHandle,states[1])
    for i=2,#states do
        simOMPL.addGoalState(taskHandle,states[i])
    end
end

--@fun getPathStateCount get the number of states in the given path
--@arg int taskHandle the handle of the task
--@arg table path the path, as returned by simOMPL.getPath
--@ret int count the number of states in the path
function simOMPL.getPathStateCount(taskHandle,path)
    local n=simOMPL.getStateSpaceDimension(taskHandle)
    return #path/n
end

--@fun getPathState extract the state at specified index from the given path
--@arg int taskHandle the handle of the task
--@arg table path the path, as returned by simOMPL.getPath
--@arg int index the index, starting from 1
--@ret table state a state extracted from the path
function simOMPL.getPathState(taskHandle,path,index)
    if index==0 then error('invalid index') end
    if index<0 then
        index=simOMPL.getPathStateCount(taskHandle,path)+index+1
    end
    local n=simOMPL.getStateSpaceDimension(taskHandle)
    local s={}
    for i=(index-1)*n+1,(index)*n do table.insert(s,path[i]) end
    return s
end

--@fun getReversedPath reverse the given path
--@arg int taskHandle the handle of the task
--@arg table path the path, as returned by simOMPL.getPath
--@ret table reversedPath the reversed path
function simOMPL.getReversedPath(taskHandle,path)
    local n=simOMPL.getStateSpaceDimension(taskHandle)
    local p={}
    for i=1,#path/n do
        local ii=#path/n-i+1
        for j=1,n do
            table.insert(p,path[(ii-1)*n+j])
        end
    end
    return p
end

--@fun projectionSize return the dimension of the projection
--@arg int taskHandle the handle of the task
--@ret int size of the projection
function simOMPL.projectionSize(taskHandle)
    local s=simOMPL.readState(taskHandle)
    local p=simOMPL.projectStates(taskHandle,s)
    return #p
end

function simOMPL.__projectionMustBe3D(taskHandle)
    if simOMPL.projectionSize(taskHandle)~=3 then
        error('this functions works only with 3D projections (pass useForProjection=1 to createStateSpace wherever appropriate, or otherwise use setProjectionEvaluationCallback to specify a custom projection to map the state into a 3D point)')
    end
end

--@fun drawPath draw a solution path for the specified motion planning task (as lines)
--@arg int taskHandle the handle of the task
--@arg table path the path, as returned by simOMPL.getPath
--@arg float lineSize size of the line (in pixels)
--@arg table color color of the lines (3 float values)
--@arg int extraAttributes extra attributes to pass to sim.addDrawingObject
--@ret table dwos a table of handles of new drawing objects
function simOMPL.drawPath(taskHandle,path,lineSize,color,extraAttributes)
    simOMPL.__projectionMustBe3D(taskHandle)
    lineSize=lineSize or 2
    parentObjectHandle=-1
    color=color or {1,0,0}
    extraAttributes=extraAttributes or 0
    sim.setThreadAutomaticSwitch(false)
    local dwoPath=sim.addDrawingObject(sim.drawing_lines+extraAttributes,lineSize,0,parentObjectHandle,99999,{1,0,0})
    local pathProjection=simOMPL.projectStates(taskHandle,path)
    for i=4,#pathProjection,3 do
        local d={}
        for j=-3,2 do table.insert(d, pathProjection[i+j]) end
        sim.addDrawingObjectItem(dwoPath,d)
    end
    sim.setThreadAutomaticSwitch(true)
    return {dwoPath}
end

--@fun drawPlannerData draw planner data (graph) extracted from the specified motion planning task
--@arg int taskHandle handle of the task
--@arg float pointSize size of nodes (in meters)
--@arg float lineSize size of lines (in pixels)
--@arg table color color of nodes and lines (3 float values)
--@arg table startColor color of start nodes (3 float values)
--@arg table goalColor color of goal nodes (3 float values)
--@ret table dwos a table of handles of new drawing objects
function simOMPL.drawPlannerData(taskHandle,pointSize,lineSize,color,startColor,goalColor)
    simOMPL.__projectionMustBe3D(taskHandle)
    local states1,tags,tagsReal,edges,edgeWeights,startVertices,goalVertices=simOMPL.getPlannerData(taskHandle)
    local states=simOMPL.projectStates(taskHandle,states1)
    pointSize=pointSize or 0.02
    lineSize=lineSize or 2
    color=color or {0.5,0.5,0.5}
    startColor=startColor or {0.5,0.5,0.5}
    goalColor=goalColor or {0.5,0.5,0.5}
    local dupTol=0
    local parentHandle=-1
    local maxItemCnt=999999
    sim.setThreadAutomaticSwitch(false)
    local dwoPoints=sim.addDrawingObject(sim.drawing_spherepoints,pointSize,dupTol,parentHandle,maxItemCnt,color)
    local dwoLines=sim.addDrawingObject(sim.drawing_lines,lineSize,dupTol,parentHandle,maxItemCnt,color)
    local dwoStart=sim.addDrawingObject(sim.drawing_spherepoints,pointSize*1.5,dupTol,parentHandle,maxItemCnt,startColor)
    local dwoGoal=sim.addDrawingObject(sim.drawing_spherepoints,pointSize*1.5,dupTol,parentHandle,maxItemCnt,goalColor)
    for i=1,#states,3 do
        local p={states[i+0],states[i+1],states[i+2]}
        sim.addDrawingObjectItem(dwoPoints,p)
    end
    for i=1,#edges,2 do
        local l={states[3*edges[i+0]+1],states[3*edges[i+0]+2],states[3*edges[i+0]+3],
                 states[3*edges[i+1]+1],states[3*edges[i+1]+2],states[3*edges[i+1]+3]}
        sim.addDrawingObjectItem(dwoLines,l)
    end
    for i=1,#startVertices do
        local p={states[3*startVertices[i]+1],states[3*startVertices[i]+2],states[3*startVertices[i]+3]}
        sim.addDrawingObjectItem(dwoStart,p)
    end
    for i=1,#goalVertices do
        local p={states[3*goalVertices[i]+1],states[3*goalVertices[i]+2],states[3*goalVertices[i]+3]}
        sim.addDrawingObjectItem(dwoGoal,p)
    end
    sim.setThreadAutomaticSwitch(true)
    return {dwoPoints,dwoLines,dwoStart,dwoGoal}
end

--@fun removeDrawingObjects remove the drawing objects created with related functions
--@arg int taskHandle handle of the task
--@arg table dwos table of handles to drawing objects, as returned by the functions
function simOMPL.removeDrawingObjects(taskHandle,dwos)
    for i,ob in pairs(dwos) do sim.removeDrawingObject(ob) end
end

return simOMPL
