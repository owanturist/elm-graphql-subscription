port module Main exposing (main)

import Counter
import GenericDict exposing (GenericDict)
import Html exposing (Html, button, div, form, h1, input, label, text)
import Html.Attributes exposing (disabled, step, style, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode exposing (Value, decodeValue)
import RemoteData exposing (RemoteData(..), WebData)
import Store exposing (Counter, ID, extractID)


-- P O R T S


port send : String -> Cmd msg


port subscribe : (Value -> msg) -> Sub msg



-- M O D E L


type alias Model =
    { entities : WebData (List Counter)
    , counters : GenericDict (ID { counter : () }) Counter.Model
    , creating : WebData Never
    , count : Int
    }


initial : ( Model, Cmd Msg )
initial =
    ( { entities = Loading
      , counters = GenericDict.empty (\left right -> compare (extractID left) (extractID right))
      , creating = NotAsked
      , count = 0
      }
    , Cmd.batch
        [ Http.send LoadDone Store.getCounters
        , send
            """
            subscription OnCreateCounter {
                onCreateCounter {
                    id
                    count
                    version
                }
            }
            """
        , send
            """
            subscription OnUpdateCounter {
                onUpdateCounter {
                    id
                    count
                    version
                }
            }
            """
        , send
            """
            subscription OnDeleteCounter {
                onDeleteCounter {
                    id
                    count
                    version
                }
            }
            """
        ]
    )



-- U P D A T E


type Msg
    = Load
    | LoadDone (Result Http.Error (List Counter))
    | Subscription Value
    | ChangeCount String
    | Create
    | CreateDone (Result Http.Error Counter)
    | CounterMsg Counter Counter.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Load ->
            ( { model | entities = Loading }
            , Http.send LoadDone Store.getCounters
            )

        LoadDone result ->
            ( { model | entities = RemoteData.fromResult result }
            , Cmd.none
            )

        Subscription value ->
            ( case decodeValue Store.counterActionsDecoder value of
                Ok (Store.Created newEntity) ->
                    case List.filter ((==) newEntity.id << .id) (RemoteData.withDefault [] model.entities) of
                        [ _ ] ->
                            model

                        _ ->
                            { model | entities = RemoteData.map ((::) newEntity) model.entities }

                Ok (Store.Updated nextEntity) ->
                    let
                        nextEntities =
                            RemoteData.map
                                (List.map
                                    (\entity ->
                                        if nextEntity.id == entity.id && nextEntity.version /= entity.version then
                                            nextEntity
                                        else
                                            entity
                                    )
                                )
                                model.entities
                    in
                    { model | entities = nextEntities }

                Ok (Store.Deleted entity) ->
                    let
                        nextEntities =
                            RemoteData.map
                                (List.filter ((/=) entity.id << .id))
                                model.entities
                    in
                    { model
                        | entities = nextEntities
                        , counters = GenericDict.remove entity.id model.counters
                    }

                Err _ ->
                    model
            , Cmd.none
            )

        ChangeCount nextCount ->
            ( { model | count = Result.withDefault 0 (String.toInt nextCount) }
            , Cmd.none
            )

        Create ->
            ( { model | creating = Loading }
            , Store.createCounter model.count
                |> Http.send CreateDone
            )

        CreateDone (Err err) ->
            ( { model | creating = Failure err }
            , Cmd.none
            )

        CreateDone (Ok entity) ->
            ( { model
                | entities = RemoteData.map ((::) entity) model.entities
                , creating = NotAsked
                , count = 0
              }
            , Cmd.none
            )

        CounterMsg counter msg ->
            case
                GenericDict.get counter.id model.counters
                    |> Maybe.withDefault Counter.initial
                    |> Counter.update msg counter
            of
                Counter.Changed nextCounter cmd ->
                    ( { model | counters = GenericDict.insert counter.id nextCounter model.counters }
                    , Cmd.map (CounterMsg counter) cmd
                    )

                Counter.Updated nextEntity ->
                    let
                        nextEntities =
                            RemoteData.map
                                (List.map
                                    (\entity ->
                                        if entity.id == counter.id then
                                            nextEntity
                                        else
                                            entity
                                    )
                                )
                                model.entities
                    in
                    ( { model
                        | entities = nextEntities
                        , counters = GenericDict.remove counter.id model.counters
                      }
                    , Cmd.none
                    )

                Counter.Deleted ->
                    let
                        nextEntities =
                            RemoteData.map
                                (List.filter ((/=) counter.id << .id))
                                model.entities
                    in
                    ( { model
                        | entities = nextEntities
                        , counters = GenericDict.remove counter.id model.counters
                      }
                    , Cmd.none
                    )



-- S U B S C R I P T I O N S


subscriptions : Model -> Sub Msg
subscriptions model =
    subscribe Subscription



-- V I E W


viewCreate : Model -> Html Msg
viewCreate model =
    let
        ( busy, error ) =
            case model.creating of
                Loading ->
                    ( True, Nothing )

                Failure err ->
                    ( False, Just (toString err) )

                _ ->
                    ( False, Nothing )
    in
    form
        [ onSubmit Create ]
        [ label [] [ text "Create a Counter" ]
        , input
            [ type_ "number"
            , step "1"
            , disabled busy
            , value (toString model.count)
            , onInput ChangeCount
            ]
            []
        , button
            [ type_ "send"
            , disabled busy
            ]
            [ text "Submit" ]
        , case error of
            Nothing ->
                text ""

            Just err ->
                text err
        ]


viewLoadButton : Html Msg
viewLoadButton =
    button
        [ type_ "button"
        , onClick Load
        ]
        [ text "Load Counters" ]


view : Model -> Html Msg
view model =
    case model.entities of
        NotAsked ->
            div [] [ viewLoadButton ]

        Loading ->
            div [] [ text "Loading..." ]

        Failure err ->
            div []
                [ text ("Something wend wrong: " ++ toString err)
                , viewLoadButton
                ]

        Success entities ->
            div []
                [ h1 [] [ text "Counters" ]
                , viewCreate model
                , div []
                    (List.map
                        (\entity ->
                            GenericDict.get entity.id model.counters
                                |> Maybe.withDefault Counter.initial
                                |> Counter.view entity
                                |> Html.map (CounterMsg entity)
                                |> List.singleton
                                |> div [ style [ ( "margin-top", "10px" ) ] ]
                        )
                        entities
                    )
                ]


main : Program Never Model Msg
main =
    Html.program
        { init = initial
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
