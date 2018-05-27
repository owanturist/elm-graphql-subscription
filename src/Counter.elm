module Counter exposing (Model, Msg, Stage(..), initial, update, view)

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (disabled, type_)
import Html.Events exposing (onClick)
import Http
import RemoteData exposing (RemoteData(..), WebData)
import Store exposing (Counter)


-- M O D E L


type Model
    = Model
        { status : WebData Never
        }


initial : Model
initial =
    Model
        { status = NotAsked
        }



-- U P D A T E


type Msg
    = Update Int
    | UpdateDone (Result Http.Error Counter)
    | Delete
    | DeleteDone (Result Http.Error ())


type Stage
    = Changed Model (Cmd Msg)
    | Updated Counter
    | Deleted


update : Msg -> Counter -> Model -> Stage
update msg counter (Model state) =
    case msg of
        Update count ->
            [ Store.toCount count
            ]
                |> Store.updateCounter counter.id counter.version
                |> Http.send UpdateDone
                |> Changed (Model { state | status = Loading })

        UpdateDone (Err err) ->
            Changed
                (Model { state | status = Failure err })
                Cmd.none

        UpdateDone (Ok counter) ->
            Updated counter

        Delete ->
            Store.deleteCounter counter.id
                |> Http.send DeleteDone
                |> Changed (Model { state | status = Loading })

        DeleteDone (Err err) ->
            Changed
                (Model { state | status = Failure err })
                Cmd.none

        DeleteDone (Ok ()) ->
            Deleted



-- V I E W


view : Counter -> Model -> Html Msg
view counter (Model state) =
    let
        ( busy, error ) =
            case state.status of
                Loading ->
                    ( True, Nothing )

                Failure err ->
                    ( False, Just (toString err) )

                _ ->
                    ( False, Nothing )
    in
    div []
        [ button
            [ type_ "button"
            , disabled busy
            , onClick (Update (counter.count - 1))
            ]
            [ text "-" ]
        , text (toString counter.count)
        , button
            [ type_ "button"
            , disabled busy
            , onClick (Update (counter.count + 1))
            ]
            [ text "+" ]
        , button
            [ type_ "button"
            , disabled busy
            , onClick Delete
            ]
            [ text "x" ]
        , case error of
            Nothing ->
                text ""

            Just err ->
                div [] [ text err ]
        ]
