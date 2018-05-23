module Main exposing (main)

import Counter
import GenericDict exposing (GenericDict)
import Html exposing (Html, button, div, form, h1, input, label, text)
import Html.Attributes exposing (disabled, step, style, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import RemoteData exposing (RemoteData(..), WebData)
import Store exposing (Counter, ID, extractID)


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
    , Http.send LoadDone Store.getCounters
    )



-- U P D A T E


type Msg
    = Load
    | LoadDone (Result Http.Error (List Counter))
    | ChangeCount String
    | Create
    | CreateDone (Result Http.Error Counter)
    | CounterMsg (ID { counter : () }) Counter.Msg


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

        CounterMsg counterId msg ->
            case
                GenericDict.get counterId model.counters
                    |> Maybe.withDefault Counter.initial
                    |> Counter.update msg counterId
            of
                Counter.Idle ->
                    ( model, Cmd.none )

                Counter.Changed nextCounter cmd ->
                    ( { model | counters = GenericDict.insert counterId nextCounter model.counters }
                    , Cmd.map (CounterMsg counterId) cmd
                    )

                Counter.Updated nextEntity ->
                    let
                        nextEntities =
                            RemoteData.map
                                (List.map
                                    (\entity ->
                                        if entity.id == counterId then
                                            nextEntity
                                        else
                                            entity
                                    )
                                )
                                model.entities
                    in
                    ( { model
                        | entities = nextEntities
                        , counters = GenericDict.remove counterId model.counters
                      }
                    , Cmd.none
                    )

                Counter.Deleted ->
                    let
                        nextEntities =
                            RemoteData.map
                                (List.filter ((/=) counterId << .id))
                                model.entities
                    in
                    ( { model
                        | entities = nextEntities
                        , counters = GenericDict.remove counterId model.counters
                      }
                    , Cmd.none
                    )



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
                                |> Html.map (CounterMsg entity.id)
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
        , subscriptions = always Sub.none
        , view = view
        }
