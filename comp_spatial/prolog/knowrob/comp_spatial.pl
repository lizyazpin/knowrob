/*
  This module contains all computables that calculate qualitative spatial relations
  between objects to allow for spatial reasoning.

  Copyright (C) 2009-13 Moritz Tenorth, Lars Kunze
  Copyright (C) 2017 Daniel Beßler
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
:- module(comp_spatial,
    [
      on_Physical/2,
      on_Physical/3,
      in_ContGeneric/2,
      in_ContGeneric/3,
      comp_toTheRightOf/2,
      comp_toTheRightOf/3,
      comp_toTheLeftOf/2,
      comp_toTheLeftOf/3,
      comp_toTheSideOf/2,
      comp_toTheSideOf/3,
      comp_inFrontOf/2,
      comp_inFrontOf/3,
      comp_inCenterOf/2,
      comp_inCenterOf/3,
      comp_below_of/2,
      comp_below_of/3,
      comp_above_of/2,
      comp_above_of/3,
      comp_center/2,
      objectAtPoint2D/2,
      objectAtPoint2D/3
    ]).
/** <module> Predicates for spatial reasoning

@author Moritz Tenorth
@author Lars Kunze
@license BSD
*/
:- use_module(library('semweb/rdfs')).
:- use_module(library('semweb/rdf_db')).
:- use_module(library('knowrob/knowrob')).
:- use_module(library('knowrob/computable')).
:- use_module(library('knowrob/objects')).
:- use_module(library('knowrob/temporal')).

:- rdf_db:rdf_register_ns(knowrob,      'http://knowrob.org/kb/knowrob.owl#',      [keep(true)]).
:- rdf_db:rdf_register_ns(comp_spatial, 'http://knowrob.org/kb/comp_spatial.owl#', [keep(true)]).

% define predicates as rdf_meta predicates
% (i.e. rdf namespaces are automatically expanded)
:-  rdf_meta
    on_Physical(r, r),
    on_Physical_at_time(r, r, +),
    in_ContGeneric(r, r),
    in_ContGeneric_at_time(r, r, +),
    comp_below_of(r,r),
    comp_below_of_at_time(r,r,+),
    comp_above_of(r,r),
    comp_above_of_at_time(r,r,+),
    comp_toTheSideOf(r, r),
    comp_toTheSideOf_at_time(r, r,+),
    comp_toTheRightOf(r, r),
    comp_toTheRightOf_at_time(r, r,+),
    comp_toTheLeftOf(r, r),
    comp_toTheLeftOf_at_time(r, r,+),
    comp_inFrontOf(r, r),
    comp_inFrontOf_at_time(r, r,+),
    comp_inCenterOf(r, r),
    comp_inCenterOf_at_time(r, r,+),
    comp_center(r, r).

physical_object(Thing) :-
  rdfs_individual_of(Thing, dul:'PhysicalObject').

%% on_Physical(?Top, ?Bottom) is nondet.
%% on_Physical(?Top, ?Bottom, +Time) is nondet.
%
% Check if Top is in the area of and above Bottom.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Top Identifier of the upper Object
% @param Bottom Identifier of the lower Object
%
on_Physical(Top, Bottom) :-
    current_time(Time),
    on_Physical(Top, Bottom, Time).

on_Physical(Top, Bottom, Time) :-
    physical_object(Top),
    map_frame_name(MapFrame),
    % get object center for Top
    object_pose(Top, [MapFrame, _, [TX,TY,TZ], _], Time),
    
    physical_object(Bottom),
    Top \= Bottom,
    % query for objects at center point
    objectAtPoint2D(TX,TY,Bottom,Time),
    % get height of objects at center point
    object_pose(Bottom, [MapFrame, _, [_,_,BZ], _], Time),

    % the criterion is if the difference between them is less than epsilon=5cm
    <( BZ, TZ).

%% comp_above_of(?Top, ?Bottom) is nondet.
%% comp_above_of(?Top, ?Bottom, +Time) is nondet.
%
% Check if Top is in the area of and above Bottom.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Top Identifier of the upper Object
% @param Bottom Identifier of the lower Object
%
comp_above_of(Top, Bottom) :-
    current_time(Time),
    comp_above_of(Top, Bottom, Time).

comp_above_of(Top, Bottom, Time) :-
    physical_object(Top),
    map_frame_name(MapFrame),
    
    % get object center for Top
    object_pose(Top, [MapFrame, _, [TX,TY,TZ], _], Time),
    
    physical_object(Bottom),
    Top \= Bottom,

    % query for objects at center point
    objectAtPoint2D(TX,TY,Bottom,Time),

    % get height of objects at center point
    object_pose(Bottom, [MapFrame, _, [_,_,BZ], _], Time),

    % the criterion is if the difference between them is less than epsilon=5cm
    <( BZ, TZ).


%% comp_below_of(?Bottom, ?Top) is nondet.
%% comp_below_of(?Bottom, ?Top, +Time) is nondet.
%
% Check if Top is in the area of and above Bottom.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Bottom Identifier of the lower Object
% @param Top Identifier of the upper Object
%
comp_below_of(Bottom, Top) :- comp_above_of(Top, Bottom).
comp_below_of(Bottom, Top, Time) :- comp_above_of(Top, Bottom, Time).


%% comp_toTheLeftOf(?Left, ?Right) is nondet.
%% comp_toTheLeftOf(?Left, ?Right, +Time) is nondet.
%
% Check if Left is to the left of Right.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Left Identifier of the left Object
% @param Right Identifier of the right Object
%
comp_toTheLeftOf(Left, Right) :-
    current_time(Time),
    comp_toTheLeftOf(Left, Right, Time).

comp_toTheLeftOf(Left, Right, Time) :-
    %
    % TODO: adapt this to take rotations and object dimensions into account
    %
    physical_object(Left),
    map_frame_name(MapFrame),
    object_pose(Left, [MapFrame, _, [LX,LY,LZ], _], Time),
    
    physical_object(Right),
    Left \= Right,
    object_pose(Right, [MapFrame, _, [RX,RY,RZ], _], Time),

    =<( abs( LX - RX), 0.30),  % less than 30cm y diff
    =<( RY, LY ),              % right obj has a smaller y coord than the left one (on the table)
    =<( abs( LZ - RZ), 0.30).  % less than 30cm height diff


%% comp_toTheRightOf(?Right,?Left) is nondet.
%% comp_toTheRightOf(?Right,?Left,+Time) is nondet.
%
% Check if Right is to the right of Left.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Right Identifier of the right Object
% @param Left Identifier of the left Object
% @see comp_toTheLeftOf
%
comp_toTheRightOf(Right, Left) :- comp_toTheLeftOf(Left, Right).
comp_toTheRightOf(Right, Left, Time) :- comp_toTheLeftOf(Left, Right, Time).


%% comp_toTheSideOf(?A, ?B) is nondet.
%% comp_toTheSideOf(?A, ?B, +Time) is nondet.
%
% Check if A is either to the left or the rigth of B.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param A Identifier of Object A
% @param B Identifier of Object B
% @see comp_toTheLeftOf
% @see comp_toTheRightOf
%
comp_toTheSideOf(A, B) :-
    once(comp_toTheRightOf(A, B); comp_toTheLeftOf(A, B)).

comp_toTheSideOf(A, B, Time) :-
    once(comp_toTheRightOf(A, B, Time); comp_toTheLeftOf(A, B, Time)).


%% comp_inFrontOf(?Front, ?Back) is nondet.
%% comp_inFrontOf(?Front, ?Back, +Time) is nondet.
%
% Check if Front is in front of Back. Currently does not take the orientation
% into account, only the position and dimension.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Front Identifier of the front Object
% @param Back Identifier of the back Object
%
comp_inFrontOf(Front, Back) :-
    current_time(Time),
    comp_inFrontOf(Front, Back, Time).

comp_inFrontOf(Front, Back, Time) :-
    %
    % TODO: adapt this to take rotations and object dimensions into account
    %
    physical_object(Front),
    map_frame_name(MapFrame),
    object_pose(Front, [MapFrame, _, [FX,_,_], _], Time),
    
    physical_object(Back),
    Front \= Back,
    object_pose(Back, [MapFrame, _, [BX,_,_], _], Time),

    =<( BX, FX ).      % front obj has a higher x coord.


%% comp_inCenterOf(?Inner, ?Outer) is nondet.
%% comp_inCenterOf(?Inner, ?Outer, +Time) is nondet.
%
% Check if Inner is in the center of OuterObj. Currently does not take the orientation
% into account, only the position and dimension.
%
% Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param Inner Identifier of the inner Object
% @param Outer Identifier of the outer Object
%
comp_inCenterOf(Inner, Outer) :-
    current_time(Time),
    comp_inCenterOf(Inner, Outer, Time).

comp_inCenterOf(Inner, Outer, Time) :-
    physical_object(Inner),
    
    map_frame_name(MapFrame),
    object_pose(Inner, [MapFrame, _, [IX,IY,IZ], _], Time),
    
    physical_object(Outer),
    Inner \= Outer,
    object_pose(Outer, [MapFrame, _, [OX,OY,OZ], _], Time),

    =<( abs( IX - OX), 0.20),  % less than 20cm x diff
    =<( abs( IY - OY), 0.20),  % less than 20cm y diff
    =<( abs( IZ - OZ), 0.20).  % less than 20cm z diff


%% in_ContGeneric(?InnerObj, ?OuterObj) is nondet.
%% in_ContGeneric(?InnerObj, ?OuterObj, +Interval) is nondet.
%
% Check if InnerObj is contained by OuterObj. Currently does not take the orientation
% into account, only the position and dimension.
%
                                % Implemented as a wrapper predicate around holds(...) that computes the relation for the
% current point in time
%
% @param InnerObj Identifier of the inner Object
% @param OuterObj Identifier of the outer Object
%
in_ContGeneric(InnerObj, OuterObj) :-
    current_time(Time),
    in_ContGeneric(InnerObj, OuterObj, Time).

in_ContGeneric(InnerObj, OuterObj, Time) :-
    
    physical_object(InnerObj),
    map_frame_name(MapFrame),
    object_pose(InnerObj, [MapFrame, _, [IX,IY,IZ], _], Time),
    object_dimensions(InnerObj, ID, IW, IH),
    
    physical_object(OuterObj),
    InnerObj \= OuterObj,
    object_pose(OuterObj, [MapFrame, _, [OX,OY,OZ], _], Time),
    object_dimensions(OuterObj, OD, OW, OH),
    
    % InnerObj is contained by OuterObj if (center_i+0.5*dim_i)<=(center_o+0.5*dim_o)
    % for all dimensions (x, y, z)
    >=( (IX - 0.5*ID), (OX - 0.5*OD)-0.05), =<( (IX + 0.5*ID),  (OX + 0.5*OD)+0.05 ),
    >=( (IY - 0.5*IW), (OY - 0.5*OW)-0.05 ), =<( (IY + 0.5*IW), (OY + 0.5*OW)+0.05 ),
    >=( (IZ - 0.5*IH), (OZ - 0.5*OH)-0.05 ), =<( (IZ + 0.5*IH), (OZ + 0.5*OH)+0.05 ).

% % % % % % % % % % % % % % % % % % % %
% matrix and vector computations (relating the homography-based
% position representation with the old center-point-based one)
%

%% comp_center(+Obj, ?Center) is semidet.
%
% Compute the center point of an object from its homography matrix
%
% @param Obj    The object identifier
% @param Center The center point identifier as a String 'translation_<rotation matrix identifier>'
comp_center(Obj, Center) :-
  rdf_triple(knowrob:orientation, Obj, Matrix),
  rdf_split_url(G, L, Matrix),
  atom_concat('translation_', L, P),
  rdf_split_url(G, P, Center).

%% objectAtPoint2D(+Point2D, ?Obj) is nondet.
%
% Compute which objects are positioned at the (x,y) coordinate of Point2D
%
% @param Point2D  Instance of a knowrob:Point2D for which the xCoord and yCoord can be computed
% @param Obj      Objects whose bounding boxes overlap this point in x,y direction
% 
objectAtPoint2D(Point2D, Obj) :-
    % get coordinates of point of interest
    rdf_triple(knowrob:xCoord, Point2D, PCxx), strip_literal_type(PCxx, PCx), atom_to_term(PCx,PX,_),
    rdf_triple(knowrob:yCoord, Point2D, PCyy), strip_literal_type(PCyy, PCy), atom_to_term(PCy,PY,_),
    objectAtPoint2D(PX,PY,Obj).

%% objectAtPoint2D(+PX, +PY, ?Obj) is nondet.
%
% Compute which objects are positioned at the given (x,y) coordinate 
%
% @param PX   X coordinate to be considered    
% @param PY   Y  coordinate to be considered
% @param Obj  Objects whose bounding boxes overlap this point in x,y direction
% @bug        THIS IS BROKEN FOR ALL NON-STANDARD ROTATIONS if the upper left matrix is partly zero
%
objectAtPoint2D(PX,PY,Obj) :-
    current_time(Time),
    objectAtPoint2D(PX,PY,Obj, Time).
 
objectAtPoint2D(PX, PY, Obj, Time) :-

    % get information of potential objects at positon point2d (x/y)
    object_dimensions(Obj, OD, OW, _),
    
    object_pose(Obj, [map,_,Pos,Rot], Time),
    matrix([M00,M01,_,OX, M10,M11,_,OY|_], Pos, Rot),

    % object must have an extension
    <(0,OW), <(0,OD),

    % calc corner points of rectangle (consider rectangular objects only!)
    P0X is (OX - 0.5*OW),
    P0Y is (OY + 0.5*OD),
    P1X is (OX + 0.5*OW),
    P1Y is (OY + 0.5*OD),
    P2X is (OX - 0.5*OW),
    P2Y is (OY - 0.5*OD),
    % rotate points
    RP0X is (OX + (P0X - OX) * M00 + (P0Y - OY) * M01),
    RP0Y is (OY + (P0X - OX) * M10 + (P0Y - OY) * M11),
    RP1X is (OX + (P1X - OX) * M00 + (P1Y - OY) * M01),
    RP1Y is (OY + (P1X - OX) * M10 + (P1Y - OY) * M11),
    RP2X is (OX + (P2X - OX) * M00 + (P2Y - OY) * M01),
    RP2Y is (OY + (P2X - OX) * M10 + (P2Y - OY) * M11),

    % debug: print rotated points
    %write('P0 X: '), write(P0X), write(' -> '), writeln(RP0X),
    %write('P0 Y: '), write(P0Y), write(' -> '), writeln(RP0Y),
    %write('P1 X: '), write(P1X), write(' -> '), writeln(RP1X),
    %write('P1 Y: '), write(P1Y), write(' -> '), writeln(RP1Y),
    %write('P2 X: '), write(P2X), write(' -> '), writeln(RP2X),
    %write('P2 Y: '), write(P2Y), write(' -> '), writeln(RP2Y),

    V1X is (RP1X - RP0X),
    V1Y is (RP1Y - RP0Y),

    V2X is (RP2X - RP0X),
    V2Y is (RP2Y - RP0Y),

    VPX is (PX - RP0X),
    VPY is (PY - RP0Y),

    DOT1 is (VPX * V1X + VPY * V1Y),
    DOT2 is (VPX * V2X + VPY * V2Y),
    DOTV1 is (V1X * V1X + V1Y * V1Y),
    DOTV2 is (V2X * V2X + V2Y * V2Y),

    =<(0,DOT1), =<(DOT1, DOTV1),
    =<(0,DOT2), =<(DOT2, DOTV2).
