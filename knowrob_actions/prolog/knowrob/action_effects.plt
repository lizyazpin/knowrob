%%
%% Copyright (C) 2016 by Daniel Beßler
%%
%% This file contains tests for the action-effect reasoning
%% tools in KnowRob.
%%
%% This program is free software; you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation; either version 3 of the License, or
%% (at your option) any later version.
%%
%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%

:- begin_tests('knowrob/action_effects').

:- use_module(library('semweb/rdf_db')).
:- use_module(library('semweb/owl')).
:- use_module(library('semweb/owl_parser')).
:- use_module(library('knowrob/knowrob')).
:- use_module(library('knowrob/computable')).
:- use_module(library('knowrob/action_model')).
:- use_module(library('knowrob/action_effects')).
:- use_module(library('knowrob/temporal')).
:- use_module(library('swrl')).
:- use_module(library('swrl_parser')).

:- owl_parse('package://knowrob_actions/owl/blocksworld.owl').
:- owl_parse('package://knowrob_actions/owl/pancake.owl').

:- rdf_db:rdf_register_ns(knowrob, 'http://knowrob.org/kb/knowrob.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(blocksworld,  'http://knowrob.org/kb/blocksworld.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(pancake,  'http://knowrob.org/kb/pancake.owl#', [keep(true)]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Blocksworld
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Load blocksworld SWRL rules
:- swrl_file_path(knowrob_actions,'blocksworld.swrl',Filepath),
   swrl_file_parse(Filepath,_,_).

yellow_on_blue  :- holds( blocksworld:ontop(blocksworld:'BlockYellow_0', blocksworld:'BlockBlue_0') ), !.
yellow_on_red   :- holds( blocksworld:ontop(blocksworld:'BlockYellow_0', blocksworld:'BlockRed_0') ), !.
yellow_on_table :- \+ holds( blocksworld:ontop(blocksworld:'BlockYellow_0', _) ), !.
red_on_blue     :- holds( blocksworld:ontop(blocksworld:'BlockRed_0', blocksworld:'BlockBlue_0') ), !.
red_on_table    :- \+ holds( blocksworld:ontop(blocksworld:'BlockRed_0', _) ), !.

:- rdf_meta create_action_for_task(r,r).

create_action_for_task(Tsk,Act) :-
  current_time(T0),
  action_create(dul:'Action',Act,belief_state),
  action_set_task(Act,Tsk),
  event_set_begin_time(Act,T0),
  event_set_end_time(Act,T0),
  forall(
  ( kb_triple(Tsk, dul:isTaskOf, Role),
    kb_triple(Role, dul:classifies, Obj) ),
    action_add_filler(Act,Obj)
  ).
  
  
test('Unstack_Y') :-
  yellow_on_blue,
  create_action_for_task(blocksworld:'Unstack_Y',Act),
  action_effects_apply(Act,blocksworld:'Unstack_Y'),
  yellow_on_table.

test('Stack_RB') :-
  red_on_table,
  create_action_for_task(blocksworld:'Stack_RB',Act),
  action_effects_apply(Act,blocksworld:'Stack_RB'),
  red_on_blue.

test('Stack_YR') :-
  yellow_on_table,
  create_action_for_task(blocksworld:'Stack_YR',Act),
  action_effects_apply(Act,blocksworld:'Stack_YR'),
  yellow_on_red.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Pancake Making
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Load blocksworld SWRL rules
%:- swrl_file_path(knowrob_actions,'pancake.swrl',Filepath),
   %swrl_file_parse(Filepath,_,_).

test(cracking_effect_destroyed_egg, [nondet]) :-
  action_effect(pancake:'CrackingAnEgg', destroyed(Egg)),
  rdf_equal(Egg,pancake:'Egg').

%test(pancake_making_turn_on_maker) :-
  %%
  %%create_action_for_task(blocksworld:'Stack_RB',Act),
  %action_effects_apply(pancake:'TurningOn_Act_0'),
  %% TODO: test that the device state has changed
  %% test that a heating process was started
  %kb_triple(pancake:'TurningOn_Act_0', knowrob:processStarted, Heating),
  %kb_triple(Heating, dul:isClassifiedBy, pancake:'HeatingProcess').
  
%test(pancake_making_crack_egg) :-
  %% create some egg yolk and egg shells
  %action_effects_apply(pancake:'CrackingAnEgg_0'),
  %once((rdf_has(pancake:'CrackingAnEgg_0', knowrob:outputsCreated, Yolk),
        %rdfs_individual_of(Yolk, pancake:'EggYolk'))).

%:- rdf_meta test_unsattisifed_restriction(r, t).
%test_unsattisifed_restriction(Resource, Restr) :-
  %owl_unsatisfied_restriction(Resource, RestrId),
  %owl_restriction(RestrId, Restr), !.
  
%test(pancake_making_mix_dough) :-
  %% objectActedOn restriction not satisfied yet!
  %test_unsattisifed_restriction(pancake:'MixPancakeDough_0',
      %restriction(knowrob:'inputsDestroyed', cardinality(1,1,pancake:'EggYolk'))),
  %% create dough by mixing flour and milk
  %plan_constrained_objects(pancake:'MakingPancakes', pancake:'MixPancakeDough_0',
        %[pancake:'CrackingAnEgg_0']),
  %% objectActedOn restriction now satisfied!
  %\+ test_unsattisifed_restriction(pancake:'MixPancakeDough_0',
      %restriction(knowrob:'inputsDestroyed', cardinality(1,1,pancake:'EggYolk'))),
  %% Check projection in store
  %once((rdf_has(pancake:'MixPancakeDough_0', knowrob:objectActedOn, Yolk),
        %rdfs_individual_of(Yolk, pancake:'EggYolk'))),
  %action_effects_apply(pancake:'MixPancakeDough_0'),
  %once((rdf_has(pancake:'MixPancakeDough_0', knowrob:outputsCreated, Dough),
        %rdfs_individual_of(Dough, pancake:'Dough'))).
  
%test(pancake_making_pour_dough) :-
  %% pour ontop of pancake maker
  %plan_constrained_objects(pancake:'MakingPancakes', pancake:'PourDoughOntoPancakeMaker_0',
        %[pancake:'CrackingAnEgg_0', pancake:'MixPancakeDough_0']),
  %rdf_has(pancake:'PourDoughOntoPancakeMaker_0', knowrob:objectTransported, Dough),
  %rdfs_individual_of(Dough, pancake:'Dough'),
  %action_effects_apply(pancake:'PourDoughOntoPancakeMaker_0'),
  %% just assert that dough is on pancake maker as required by baking rules
  %rdf_assert(Dough, knowrob:thermicallyConnectedTo, pancake:'PancakeMaker_0'),
  %rdf_assert(pancake:'PancakeMaker_0', knowrob:thermicallyConnectedTo, Dough).

:- end_tests('knowrob/action_effects').
