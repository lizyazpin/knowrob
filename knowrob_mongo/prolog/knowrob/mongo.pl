/*
  Copyright (C) 2013 Moritz Tenorth
  Copyright (C) 2015 Daniel Beßler
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
      * Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.
      * Neither the name of the <organization> nor the
        names of its contributors may be used to endorse or promote products
        derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
:- module(knowrob_mongo,
    [
      mng_interface/1,      % get handle to the java object of the mongo client
      mng_create_index/2,
      mng_dump/1,
      mng_restore/1,
      mng_db/1,             % set the database state
      mng_timestamp/2,
      mng_distinct_values/3,
      mng_value_object/2,   % converts between mongo and prolog representations
      mng_store/3,
      mng_update/3,
      mng_collection/1,
      mng_drop/1,
      mng_get_boolean/3,
      mng_get_double/3,
      mng_get_int/3,
      mng_get_long/3,
      mng_get_string/3,
      mng_query/2,          % querying the db based on patterns of data records
      mng_query/3,
      mng_query_latest/4,
      mng_query_latest/5,
      mng_query_earliest/4,
      mng_query_earliest/5,
      mng_cursor/3,         % get a cursor to your query for some advanced processing beyond the mng_query* predicates
      mng_cursor_read/2,
      mng_cursor_descending/3,
      mng_cursor_ascending/3,
      mng_cursor_limit/3,
      mng_republish/3,
      mng_republish/4,
      mng_ros_message/2
    ]).
/** <module> Integration of mongo data into symbolic reasoning in KnowRob

@author Moritz Tenorth
@author Daniel Beßler
@license BSD
*/
:- use_module(library('semweb/rdf_db')).
:- use_module(library('semweb/rdfs')).
:- use_module(library('semweb/owl')).
:- use_module(library('http/json')).
:- use_module(library('jpl')).
:- use_module(library('knowrob/utility/filesystem')).

:-  rdf_meta
    mng_interface(-),
    mng_db(+),
    mng_timestamp(r,r),
    mng_distinct_values(+,+,-),
    mng_query_latest(+,?,+,r),
    mng_query_latest(+,?,+,r,+),
    mng_query_earliest(+,?,+,r),
    mng_query_earliest(+,?,+,r,+),
    mng_query(+,?),
    mng_query(+,?,+),
    mng_store(+,t,-),
    mng_update(+,+,t),
    mng_get_boolean(+,+,-),
    mng_get_double(+,+,-),
    mng_get_int(+,+,-),
    mng_get_long(+,+,-),
    mng_get_string(+,+,-),
    mng_value_object(+,-),
    mng_ros_message(t,-),
    mng_republish(t,+,-),
    mng_republish(+,+,-,+).

:- rdf_db:rdf_register_ns(knowrob, 'http://knowrob.org/kb/knowrob.owl#', [keep(true)]).

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% querying the mongo database

%% mng_interface(-Mongo) is det
%
% Get handle to the java object of mongo client.
%
mng_interface(Mongo) :-
    (\+ current_predicate(v_mng_interface, _)),
    jpl_new('org.knowrob.interfaces.mongo.MongoDBInterface', [], Mongo),
    assert(v_mng_interface(Mongo)),!.
mng_interface(Mongo) :-
    current_predicate(v_mng_interface, _),
    v_mng_interface(Mongo).

%% mng_create_index(+Collection,+Keys) is det
%
% Creates search index.
%
mng_create_index(_,[]) :- !.
mng_create_index(Collection,Keys) :-
  mng_interface(Mongo),
  jpl_list_to_array(Keys, KeysArr),
  jpl_call(Mongo, 'createIndex', [Collection,KeysArr], _).

%% mng_collection(?Collection) is det
%
% True iff *Collection* is an existing collection
% in the current DB.
%
mng_collection(Collection) :-
  mng_interface(Mongo),
  jpl_call(Mongo, 'getCollections', [], CollectionsArr),
  jpl_array_to_list(CollectionsArr, Collections),
  member(Collection, Collections).

%% mng_dump(+Dir) is det.
%
% Dump mongo DB.
%
mng_dump(Dir) :-
  mkdir(Dir),
  exists_directory(Dir),
  mng_interface(Mongo),
  jpl_call(Mongo, 'dump', [Dir], _).

%% mng_restore(+Dir) is det.
%
% Restore mongo DB.
%
mng_restore(Dir) :-
  exists_directory(Dir),
  mng_interface(Mongo),
  jpl_call(Mongo, 'restore', [Dir], _).

%% mng_db(+DBName) is nondet.
%
% Change mongo database state used by KnowRob.
% Note: This is currently not threadsafe!
%
% @param DBName  The name of the db (e.g., 'roslog')
%
mng_db(DBName) :-
  ground(DBName),
  mng_interface(Mongo),
  jpl_call(Mongo, 'setDatabase', [DBName], _).

mng_db(DBName) :-
  var(DBName),
  mng_interface(Mongo),
  jpl_call(Mongo, 'getDatabaseName', [], DBName).

%% mng_timestamp(+Date, -Stamp) is nondet.
%
% Computes a timestamp that corresponds to the specified date.
% date format must be as follows: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
%
% @param Date        String representation of a date
% @param Stamp       Floating point timestamp that represents the date
%
mng_timestamp(Date, Stamp) :-
  mng_interface(DB),
  jpl_call(DB, 'getMongoTimestamp', [Date], Stamp).

%% mng_distinct_values(+Collection, +Key, -Values) is nondet.
% 
% Determine distinct values of the records with Key in Collection.
%
% @param Collection The name of the MONGO DB collection
% @param Key    The field key
% @param Values List of distinct values
% 
mng_distinct_values(Collection, Key, Values) :-
  mng_interface(DB),
  jpl_call(DB, 'distinctValues', [Collection,Key], ValuesArr),
  jpl_array_to_list(ValuesArr, Values).

%%
mng_keys_relations_values(Pattern,KeysArray,RelationsArray,ValuesArray) :-
  findall(Key, member([Key,_,_],Pattern), Keys),
  findall(Rel, member([_,Rel,_],Pattern), Relations),
  findall(Obj, (
      member([_,_,Val], Pattern),
      once(mng_value_object(Val, Obj))
  ), Values),
  jpl_list_to_array(Keys, KeysArray),
  jpl_list_to_array(Relations, RelationsArray),
  jpl_list_to_array(Values, ValuesArray).

%% mng_cursor(+Collection, +Pattern, -DBCursor)
%
% Create a DB cursor of query results for records in
% Collection.
% The resulting DB object(s) match the query pattern Pattern.
%
% @param Collection The name of the MONGO DB collection
% @param DBCursor The resulting DB cursor
% @param Pattern The query pattern
%
mng_cursor(Collection, Pattern, DBCursor) :-
  mng_interface(DB),
  flatten_pattern(DB,Pattern,Flattened),
  mng_keys_relations_values(Flattened,Keys,Relations,Values),
  jpl_call(DB, 'query', [Collection,Keys,Relations,Values], DBCursor),
  not(DBCursor = @(null)).

%%
flatten_pattern(_,[],[]) :- !.

flatten_pattern(DB, [or(List)|Xs],[['',or,DBObject]|Ys]) :- !,
  mng_keys_relations_values(List,Keys,Relations,Values),
  jpl_call(DB,'disjunction',[Keys,Relations,Values], DBObject),
  not(DBObject = @(null)),
  flatten_pattern(DB, Xs, Ys).

flatten_pattern(DB, [X|Xs],[X|Ys]) :-
  flatten_pattern(DB, Xs, Ys).

%% mng_store(+Collection, +Dict, -DBObject)
%
% Stores a dictionary in a mongo DB collection
% with the provided name.
%
mng_store(Collection, Dict, DBObject) :-
  mng_interface(DB),
  with_output_to(atom(JSON), 
    json_write_dict(current_output, Dict)
  ),
  jpl_call(DB, 'store', [Collection, JSON], DBObject).

%% mng_update(+Collection,+DBObject, +Dict)
%
% Puts all key-value pairs into the given document
% *DBObject*, possibly overwriting old values.
% *Dict* is a Prolog dictionary.
%
mng_update(Collection, DBObject, Dict) :-
  mng_interface(DB),
  with_output_to(atom(JSON), 
    json_write_dict(current_output, Dict)
  ),
  jpl_call(DB, 'update', [Collection,DBObject,JSON], _).

%% mng_drop(+Collection)
%
% Drop a collection.
%
mng_drop(Collection) :-
  mng_interface(DB),
  jpl_call(DB, 'drop', [Collection], _).

%% mng_query_latest(+Collection, -DBObj, +TimeKey, +TimeValue).
%% mng_query_latest(+Collection, -DBObj, +TimeKey, +TimeValue, +Pattern).
%% mng_query_earliest(+Collection, -DBObj, +TimeKey, +TimeValue).
%% mng_query_earliest(+Collection, -DBObj, +TimeKey, +TimeValue, +Pattern).
%% mng_query(+Collection, -DBObj).
%% mng_query(+Collection, -DBObj, +Pattern).
%
% Query for DB object in Collection.
% If a query pattern is given then the resulting DB object(s) must match this pattern.
% DBObj is a term of the form: one(X), all(X) or some(X,Count) where Count is an integer.
% The results are sorted ascending or descending w.r.t. the key TimeKey if given.
%
% @param Collection The name of the MONGO DB collection
% @param DBObj The resulting DB object(s)
% @param TimeKey The DB key used for sorting
% @param TimeValue DB objects earlier/later are ignored (depending on sort mode)
% @param Pattern The query pattern
%
mng_query_latest(Collection, DBObj, TimeKey, TimeValue) :-
  mng_query_latest(Collection, DBObj, TimeKey, TimeValue, []).

mng_query_latest(Collection, DBObj, TimeKey, TimeValue, Pattern) :-
  mng_cursor(Collection, [[TimeKey, '<', date(TimeValue)]|Pattern], DBCursor),
  mng_cursor_descending(DBCursor, TimeKey, DBCursorDescending),
  mng_cursor_read(DBCursorDescending, DBObj).

mng_query_earliest(Collection, DBObj, TimeKey, TimeValue) :-
  mng_query_earliest(Collection, DBObj, TimeKey, TimeValue, []).

mng_query_earliest(Collection, DBObj, TimeKey, TimeValue, Pattern) :-
  mng_cursor(Collection, [[TimeKey, '>', date(TimeValue)]|Pattern], DBCursor),
  mng_cursor_ascending(DBCursor, TimeKey, DBCursorAscending),
  mng_cursor_read(DBCursorAscending, DBObj).

mng_query_between(Collection, DBObj, TimeKey, [Begin,End]) :-
  mng_query_between(Collection, DBObj, TimeKey, [Begin,End], []).

mng_query_between(Collection, DBObj, TimeKey, [Begin,End], Pattern) :-
  mng_cursor(Collection, [
    [TimeKey, '<', date(End)],
    [TimeKey, '>', date(Begin)]|Pattern], DBCursor),
  mng_cursor_ascending(DBCursor, TimeKey, DBCursorAscending),
  mng_cursor_read(DBCursorAscending, DBObj).

mng_query(Collection, DBObj) :-
  mng_interface(DB),
  jpl_call(DB, 'query', [Collection], DBCursor),
  not(DBCursor = @(null)),
  mng_cursor_read(DBCursor, DBObj).

mng_query(Collection, DBObj, Pattern) :-
  mng_cursor(Collection, Pattern, DBCursor),
  mng_cursor_read(DBCursor, DBObj).

%% mng_cursor_descending(+In, +Key, -Out).
%% mng_cursor_ascending(+In, +Key, -Out).
%
% Sorts the DB cursor In w.r.t. Key, the sorted collection
% can be accessed via the new DB cursor Out.
%
% @param In Input DB cursor
% @param Key The sort key
% @param Out Output DB cursor
%
mng_cursor_descending(DBCursor, Key, DBCursorDescending) :-
  mng_interface(DB),
  jpl_call(DB, 'descending', [DBCursor, Key], DBCursorDescending).

mng_cursor_ascending(DBCursor, Key, DBCursorAscending) :-
  mng_interface(DB),
  jpl_call(DB, 'ascending', [DBCursor, Key], DBCursorAscending).

%% mng_cursor_limit(+In:javaobject, +N:integer, -Out:javaobject).
%
% Out is the same mongo DB cursor as In but limited to N results.
%
mng_cursor_limit(DBCursor, N, DBCursorLimited) :-
  mng_interface(DB),
  jpl_call(DB, 'limit', [DBCursor, N], DBCursorLimited).

%% mng_cursor_read(+DBCursor, -DBObj)
%
% Read DB objects from cursor.
%
% @param DBCursor The DB cursor
% @param DBObj The resulting DB object(s)
%
mng_cursor_read(DBCursor, DBObj) :-
  setup_call_cleanup(
    mng_interface(DB),
    mng_cursor_read__(DB, DBCursor, DBObj),
    jpl_call(DBCursor, 'close', [], _)).

mng_cursor_read__(DB, DBCursor,DBObj) :-
  jpl_call(DB, 'one', [DBCursor], O1),
  not(O1 = @(null)),
  ( DBObj=O1 ; mng_cursor_read__(DB,DBCursor,DBObj) ).

%% mng_cursor_read(+DBCursor, +DBObjects).
%
% Read DB objects from cursor.
% DBObjects is one of one(DBObj), all(DBObj), or some(DBObj,Count).
%
% @param DBCursor The DB cursor
% @param DBObj The resulting DB object(s)
%
mng_db_object(DBCursor, one(DBObj)) :-
  mng_interface(DB),
  mng_cursor_limit(DBCursor, 1, DBCursorLimited),
  jpl_call(DB, 'one', [DBCursorLimited], DBObj),
  not(DBObj = @(null)).

mng_db_object(DBCursor, some(DBObjs, Count)) :-
  mng_interface(DB),
  mng_cursor_limit(DBCursor, Count, DBCursorLimited),
  jpl_call(DB, 'some', [DBCursorLimited, Count], DBObjsArray),
  not(DBObjsArray = @(null)),
  jpl_array_to_list(DBObjsArray, DBObjs).

mng_db_object(DBCursor, all(DBObjs)) :-
  mng_interface(DB),
  jpl_call(DB, 'all', [DBCursor], DBObjsArray),
  not(DBObjsArray = @(null)),
  jpl_array_to_list(DBObjsArray, DBObjs).

%% mng2pl(+Obj_mng,?Obj_pl)
mng2pl(DBObject,Dict) :-
  jpl_object_to_class(DBObject, C),
  jpl_class_to_classname(C, 'com.mongodb.DBObject'),!,
  %%
  catch(jpl_call(DBObject, 'keySet', [], KeySet),_,fail),
  findall(Key-Val, (
    jpl_set_element(KeySet,Key),
    catch(jpl_call(DBObject, 'get', [Key], Val_mng),_,fail),
    mng2pl(Val_mng,Val)
  ), Pairs),
  dict_pairs(Dict,_,Pairs).
  
mng2pl(Array,List) :-
  jpl_object_to_type(Array,array(_)), !,
  jpl_array_to_list(Array,Xs),
  findall(Y, (
    member(X,Xs),
    mng2pl(X,Y)
  ), List).

mng2pl(X,X) :- !.

%% mng_value_object(+Val, ObjJava).
%
% Convert value to Java type compatible with MONGO queries.
%
% @param Val The value
% @param ObjJava Java value compatible with MONGO queries
%
mng_value_object(date(Val), ObjJava) :-
  atom(Val), time_term(Val,T),
  mng_value_object(date(T), ObjJava), !.

mng_value_object(date(Val), ObjJava) :-
  number(Val),
  Miliseconds is Val * 1000.0,
  jpl_new('java.lang.Double', [Miliseconds], MilisecondsDouble), 
  jpl_call(MilisecondsDouble, 'longValue', [], MilisecondsLong),
  jpl_new('org.knowrob.interfaces.mongo.types.ISODate', [MilisecondsLong], ISODate),
  jpl_call(ISODate, 'getDate', [], ObjJava), !.

mng_value_object(Val, ObjJava) :-
  integer(Val),
  jpl_new('java.lang.Long', [Val], ObjJava), !.

mng_value_object(Val, ObjJava) :-
  number(Val),
  jpl_new('java.lang.Double', [Val], ObjJava), !.

mng_value_object(true, ObjJava) :-
  jpl_new('java.lang.Boolean', [@(true)], ObjJava), !.

mng_value_object(false, ObjJava) :-
  jpl_new('java.lang.Boolean', [@(false)], ObjJava), !.

mng_value_object(Val, Val) :-
  (atom(Val) ; jpl_is_object(Val)), !.

mng_value_object(Val, _) :-
  print_message(warning, domain_error(mng_value_object, [Val])), fail.

%% mng_get_boolean(+DBObject,+Key,?Value)
%% mng_get_double(+DBObject,+Key,?Value)
%% mng_get_int(+DBObject,+Key,?Value)
%% mng_get_long(+DBObject,+Key,?Value)
%% mng_get_string(+DBObject,+Key,?Value)
%
% Retrieve typed value of a field in
% a mongo DB document.
%
mng_get_boolean(DBObject,Key,Value) :-
  atom(Key), jpl_is_object(DBObject),
  catch(jpl_call(DBObject, 'getBoolean', [Key], Value),_,fail).

mng_get_double(DBObject,Key,Value) :-
  atom(Key), jpl_is_object(DBObject),
  catch(jpl_call(DBObject, 'getDouble', [Key], Value),_,fail).

mng_get_int(DBObject,Key,Value) :-
  atom(Key), jpl_is_object(DBObject),
  catch(jpl_call(DBObject, 'getInt', [Key], Value),_,fail).

mng_get_long(DBObject,Key,Value) :-
  atom(Key), jpl_is_object(DBObject),
  catch(jpl_call(DBObject, 'getLong', [Key], Value),_,fail).

mng_get_string(DBObject,Key,Value) :-
  atom(Key), jpl_is_object(DBObject),
  catch(jpl_call(DBObject, 'getString', [Key], Value),_,fail).

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% republishing of stored messages

%% mng_republish(+TypedDBObj, +Topic, -Msg).
%% mng_republish(+DBObj, +Topic, -Msg, +TypeString).
%
% Generate a ROS message based on Mongo DB object
% and publish the message on a specified topic.
% TypedDBObj is one of bool(DBObj), str(DBObj), float32(DBObj),
% float64(DBObj), int32(DBObj), int64(DBObj), image(DBObj),
% pcl(DBObj), camera(DBObj), or tf(DBObj).
%
% @param TypedDBObj The DB object (result of a query)
% @param Topic The message topic
% @param TypeString The message type identifier (e.g., 'std_msgs/Bool')
% @param Msg The generated message
%
mng_republish(bool(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'std_msgs/Bool').

mng_republish(str(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'std_msgs/String').

mng_republish(float32(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'std_msgs/Float32').

mng_republish(float64(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'std_msgs/Float64').

mng_republish(int32(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'std_msgs/Int32').

mng_republish(int64(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'std_msgs/Int64').

mng_republish(image(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'sensor_msgs/Image').

mng_republish(compressed_image(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'sensor_msgs/CompressedImage').

mng_republish(pcl(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'sensor_msgs/PointCloud').

mng_republish(camera(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'sensor_msgs/CameraInfo').

mng_republish(tf(DBObj), Topic, Msg) :-
  mng_republish(DBObj, Topic, Msg, 'tf/tfMessage').

mng_republish(DBObj, Topic, Msg, TypeString) :-
  mng2pl(DBObj,Msg),
  ros_publish(Topic, TypeString, Msg).

%% mng_ros_message(+DBObj, -Msg).
%
% Generate a ROS message based on Mongo DB object.
%
% @param DBObj The DB object (result of a query)
% @param Msg The generated message
%
mng_ros_message(DBObj, Msg) :-
  mng2pl(DBObj,Msg).
