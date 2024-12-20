class ZCL_ZOV_VICENTE_DPC_EXT definition
  public
  inheriting from ZCL_ZOV_VICENTE_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION
    redefinition .
protected section.

  methods OVCABSET_CREATE_ENTITY
    redefinition .
  methods OVCABSET_DELETE_ENTITY
    redefinition .
  methods OVCABSET_GET_ENTITY
    redefinition .
  methods OVCABSET_GET_ENTITYSET
    redefinition .
  methods OVCABSET_UPDATE_ENTITY
    redefinition .
  methods OVITEMSET_CREATE_ENTITY
    redefinition .
  methods OVITEMSET_DELETE_ENTITY
    redefinition .
  methods OVITEMSET_GET_ENTITY
    redefinition .
  methods OVITEMSET_GET_ENTITYSET
    redefinition .
  methods OVITEMSET_UPDATE_ENTITY
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZOV_VICENTE_DPC_EXT IMPLEMENTATION.


  method OVCABSET_CREATE_ENTITY.
  DATA: ld_lastid TYPE int4.
  DATA: ls_cab    TYPE zovcab.

  DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

  io_data_provider->read_entry_data(
    IMPORTING
      es_data = er_entity
  ).

  MOVE-CORRESPONDING er_entity TO ls_cab.

  ls_cab-criacao_data    = sy-datum.
  ls_cab-criacao_hora    = sy-uzeit.
  ls_cab-criacao_usuario = sy-uname.

  SELECT SINGLE MAX( ordemid )
    INTO ld_lastid
    FROM zovcab.

  ls_cab-ordemid = ld_lastid + 1.
  INSERT zovcab FROM ls_cab.
  IF sy-subrc <> 0.
    lo_msg->add_message_text_only(
      EXPORTING
        iv_msg_type = 'E'
        iv_msg_text = 'Erro ao inserir ordem de venda'
    ).

    RAISE EXCEPTION type /iwbep/cx_mgw_busi_exception
      EXPORTING
        message_container = lo_msg.
  ENDIF.

  " atualizando
  MOVE-CORRESPONDING ls_cab TO er_entity.

  CONVERT
    DATE ls_cab-criacao_data
    TIME ls_cab-criacao_hora
    INTO TIME STAMP er_entity-datacriacao
    TIME ZONE 'UTC'. "sy-zonlo.

  endmethod.


  method OVITEMSET_CREATE_ENTITY.
  DATA: ls_item TYPE zovitem.

  DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

  io_data_provider->read_entry_data(
    IMPORTING
      es_data = er_entity
  ).

  MOVE-CORRESPONDING er_entity TO ls_item.

  IF er_entity-itemid = 0.
    SELECT SINGLE MAX( itemid )
      INTO er_entity-itemid
      FROM zovitem
     WHERE ordemid = er_entity-ordemid.

    er_entity-itemid = er_entity-itemid + 1.
  ENDIF.

  INSERT zovitem FROM ls_item.
  IF sy-subrc <> 0.
    lo_msg->add_message_text_only(
      EXPORTING
        iv_msg_type = 'E'
        iv_msg_text = 'Erro ao inserir item da ordem da venda'
    ).

    RAISE EXCEPTION type /iwbep/cx_mgw_busi_exception
      EXPORTING
        message_container = lo_msg.
  ENDIF.
  endmethod.


  METHOD ovcabset_get_entityset.
    DATA: lt_cab       TYPE STANDARD TABLE OF zovcab.
    DATA: ls_cab       TYPE zovcab.
    DATA: ls_entityset LIKE LINE OF et_entityset.

    DATA: lt_orderby   TYPE STANDARD TABLE OF string.
    DATA: ld_orderby   TYPE string.

    " montando orderby dinâmico
    LOOP AT it_order INTO DATA(ls_order).
      TRANSLATE ls_order-property TO UPPER CASE.
      TRANSLATE ls_order-order TO UPPER CASE.
      IF ls_order-order = 'DESC'.
        ls_order-order = 'DESCENDING'.
      ELSE.
        ls_order-order = 'ASCENDING'.
      ENDIF.
      APPEND |{ ls_order-property } { ls_order-order }|
          TO lt_orderby.
    ENDLOOP.
    CONCATENATE LINES OF lt_orderby INTO ld_orderby SEPARATED BY ''.

    " ordenação obrigatória caso nenhuma seja definida
    IF ld_orderby = '' .
      ld_orderby = 'OrdemId ASCENDING'.
    ENDIF.

    SELECT *
      FROM zovcab_rj
     WHERE (iv_filter_string)
  ORDER BY (ld_orderby)
      INTO TABLE @lt_cab
     UP TO @is_paging-top ROWS
    OFFSET @is_paging-skip.

    LOOP AT lt_cab INTO ls_cab.
      CLEAR ls_entityset.
      MOVE-CORRESPONDING ls_cab TO ls_entityset.

      ls_entityset-criadopor = ls_cab-criacao_usuario.

      CONVERT DATE ls_cab-criacao_data
              TIME ls_cab-criacao_hora
         INTO TIME STAMP ls_entityset-datacriacao
         TIME ZONE 'UTC'. "sy-zonlo.

      APPEND ls_entityset TO et_entityset.
    ENDLOOP.
  ENDMETHOD.


  method OVITEMSET_GET_ENTITYSET.
  DATA: ld_ordemid       TYPE int4.
  DATA: lt_ordemid_range TYPE RANGE OF int4.
  DATA: ls_ordemid_range LIKE LINE OF lt_ordemid_range.
  DATA: ls_key_tab       LIKE LINE OF it_key_tab.

  " input
  READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.
  IF sy-subrc = 0.
    ld_ordemid = ls_key_tab-value.

    CLEAR ls_ordemid_range.
    ls_ordemid_range-sign   = 'I'.
    ls_ordemid_range-option = 'EQ'.
    ls_ordemid_range-low    = ld_ordemid.
    APPEND ls_ordemid_range TO lt_ordemid_range.
  ENDIF.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE et_entityset
    FROM zovitem
   WHERE ordemid IN lt_ordemid_range.

  endmethod.


  method OVCABSET_GET_ENTITY.
    DATA: ld_ordemid TYPE zovcab_aline-ordemid.
    DATA: ls_key_tab LIKE LINE OF it_key_tab.
    DATA: ls_cab     TYPE zovcab_aline.

    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    " input
    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.
    IF sy-subrc <> 0.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id da ordem de venda não informado'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.
    ld_ordemid = ls_key_tab-value.

    SELECT SINGLE *
      INTO ls_cab
      FROM zovcab_aline
     WHERE ordemid = ld_ordemid.

    IF sy-subrc = 0.
      MOVE-CORRESPONDING ls_cab TO er_entity.

      er_entity-criadopor = ls_cab-criacao_usuario.

      CONVERT DATE ls_cab-criacao_data
              TIME ls_cab-criacao_hora
         INTO TIME STAMP er_entity-datacriacao
         TIME ZONE 'UTC'. "sy-zonlo.
    ELSE.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id da ordem não encontrado'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.  endmethod.


  METHOD ovcabset_update_entity.
    DATA: ld_error TYPE flag.

    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    io_data_provider->read_entry_data(
      IMPORTING
        es_data = er_entity
    ).

    er_entity-ordemid = it_key_tab[ name = 'OrdemId' ]-value.

    " validações
    IF er_entity-clienteid = 0.
      ld_error = 'X'.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Cliente vazio'
      ).
    ENDIF.

    IF er_entity-totalordem < 10.
      ld_error = 'X'.
      lo_msg->add_message(
        EXPORTING
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZOV_RJ'
          iv_msg_number = 1
          iv_msg_v1     = 'R$ 10,00'
          iv_msg_v2     = |{ er_entity-ordemid }|
      ).
    ENDIF.

    IF ld_error = 'X'.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg
          http_status_code  = 500.
    ENDIF.

    UPDATE zovcab_aline
       SET clienteid  = er_entity-clienteid
           totalitens = er_entity-totalitens
           totalfrete = er_entity-totalfrete
           totalordem = er_entity-totalordem
           status     = er_entity-status
     WHERE ordemid    = er_entity-ordemid.

    IF sy-subrc <> 0.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao atualizar ordem'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.
  ENDMETHOD.


  METHOD ovitemset_get_entity.
    DATA: ls_key_tab LIKE LINE OF it_key_tab.
    DATA: ls_item    TYPE zovitem.
    DATA: ld_error   TYPE flag.

    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    " input
    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.
    IF sy-subrc <> 0.
      ld_error = 'X'.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id da ordem de venda não informado'
      ).
    ENDIF.
    ls_item-ordemid = ls_key_tab-value.

    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'ItemId'.
    IF sy-subrc <> 0.
      ld_error = 'X'.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id do item não informado'
      ).
    ENDIF.
    ls_item-itemid = ls_key_tab-value.

    IF ld_error = 'X'.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.

    SELECT SINGLE *
      INTO ls_item
      FROM zovitem_ALINE
     WHERE ordemid = ls_item-ordemid
       AND itemid  = ls_item-itemid.

    IF sy-subrc = 0.
      MOVE-CORRESPONDING ls_item TO er_entity.
    ELSE.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Item não encontrado'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.
ENDMETHOD.


  method OVITEMSET_UPDATE_ENTITY.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    io_data_provider->read_entry_data(
      IMPORTING
        es_data = er_entity
    ).

    er_entity-ordemid  = it_key_tab[ name = 'OrdemId' ]-value.
    er_entity-itemid   = it_key_tab[ name = 'ItemId' ]-value.
    er_entity-precotot = er_entity-quantidade * er_entity-precouni.

    UPDATE zovitem_aline
       SET material   = er_entity-material
           descricao  = er_entity-descricao
           quantidade = er_entity-quantidade
           precouni   = er_entity-precouni
           precotot   = er_entity-precotot
     WHERE ordemid    = er_entity-ordemid
       AND itemid     = er_entity-itemid.

    IF sy-subrc <> 0.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao atualizar item'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.
  endmethod.


  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
    DATA : ls_deep_entity  TYPE zcl_zov_mpc_ext=>ty_ordem_item.
    DATA : ls_deep_item    TYPE zcl_zov_mpc_ext=>ts_ovitem.

    DATA : ls_cab          TYPE zovcab_rj.
    DATA : lt_item         TYPE STANDARD TABLE OF zovitem_rj.
    DATA : ls_item         TYPE zovitem_rj.
    DATA : ld_updkz        TYPE char1.
    DATA : ld_datahora(14) TYPE c.

    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    CALL METHOD io_data_provider->read_entry_data
      IMPORTING
        es_data = ls_deep_entity.

    " cabeçalho
    IF ls_deep_entity-ordemid = 0.
      ld_updkz = 'I'.

      MOVE-CORRESPONDING ls_deep_entity TO ls_cab.

      "ls_cab-criacao_data    = sy-datum.
      "ls_cab-criacao_hora    = sy-uzeit.
      "ls_cab-criacao_usuario = sy-uname.

      ld_datahora            = ls_deep_entity-datacriacao.
      ls_cab-criacao_data    = ld_datahora(8).
      ls_cab-criacao_hora    = ld_datahora+8(6).
      ls_cab-criacao_usuario = ls_deep_entity-criadopor.

      SELECT SINGLE MAX( ordemid )
        INTO ls_cab-ordemid
        FROM zovcab_rj.

      ls_cab-ordemid = ls_cab-ordemid + 1.
    ELSE.
      ld_updkz = 'U'.

      " carregando dados atuais
      SELECT SINGLE *
        INTO ls_cab
        FROM zovcab_rj
       WHERE ordemid = ls_deep_entity-ordemid.

      ls_cab-clienteid  = ls_deep_entity-clienteid.
      ls_cab-status     = ls_deep_entity-status.
      ls_cab-totalitens = ls_deep_entity-totalitens.
      ls_cab-totalfrete = ls_deep_entity-totalfrete.
      ls_cab-totalordem = ls_cab-totalitens + ls_cab-totalfrete.
    ENDIF.

    " item
    LOOP AT ls_deep_entity-toovitem INTO ls_deep_item.
      MOVE-CORRESPONDING ls_deep_item TO ls_item.

      ls_item-ordemid = ls_cab-ordemid.
      APPEND ls_item TO lt_item.
    ENDLOOP.

    " persistência cabeçalho
    IF ld_updkz = 'I'.
      INSERT zovcab_rj FROM ls_cab.
      IF sy-subrc <> 0.
        ROLLBACK WORK.

        lo_msg->add_message_text_only(
          EXPORTING
            iv_msg_type = 'E'
            iv_msg_text = 'Erro ao inserir ordem'
        ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg.
      ENDIF.
    ELSE.
      MODIFY zovcab_rj FROM ls_cab.
      IF sy-subrc <> 0.
        ROLLBACK WORK.

        lo_msg->add_message_text_only(
          EXPORTING
            iv_msg_type = 'E'
            iv_msg_text = 'Erro ao atualizar ordem'
        ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg.
      ENDIF.
    ENDIF.

    " persistência itens
    DELETE FROM zovitem_rj WHERE ordemid = ls_cab-ordemid.

    " verifica se há itens para inserir.
    IF lines( lt_item ) > 0.
      INSERT zovitem_rj FROM TABLE lt_item.
      IF sy-subrc <> 0.
        ROLLBACK WORK.

        lo_msg->add_message_text_only(
          EXPORTING
            iv_msg_type = 'E'
            iv_msg_text = 'Erro ao inserir itens'
        ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg.
      ENDIF.
    ENDIF.

    COMMIT WORK AND WAIT.

    " atualizando deep entity de retorno

    " cabeçalho
    ls_deep_entity-ordemid = ls_cab-ordemid.
    CONVERT DATE ls_cab-criacao_data
            TIME ls_cab-criacao_hora
            INTO TIME STAMP ls_deep_entity-datacriacao
            TIME ZONE 'UTC'. "sy-zonlo.

    " item
    LOOP AT ls_deep_entity-toovitem ASSIGNING FIELD-SYMBOL(<ls_deep_item>).
      <ls_deep_item>-ordemid = ls_cab-ordemid.
    ENDLOOP.

    CALL METHOD me->copy_data_to_ref
      EXPORTING
        is_data = ls_deep_entity
      CHANGING
        cr_data = er_deep_entity.

  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
  DATA: ld_ordemid  TYPE zovcab_RJ-ordemid.
  DATA: ld_status   TYPE zovcab_RJ-status.
  DATA: lt_bapiret2 TYPE STANDARD TABLE OF zcl_zov_VICENTE_mpc_ext=>ts_mensagem.
  DATA: ls_bapiret2 TYPE zcl_zov_VICENTE_mpc_ext=>ts_mensagem.

  DATA: lt_bapiret22 TYPE STANDARD TABLE OF zcl_zov_VICENTE_mpc_ext=>mensagem2.
  DATA: ls_bapiret22 TYPE zcl_zov_VICENTE_mpc_ext=>mensagem2.


  IF iv_action_name = 'ZFI_ATUALIZA_STATUS'.
    ld_ordemid = it_parameter[ name = 'ID_ORDEMID' ]-value.
    ld_status  = it_parameter[ name = 'ID_STATUS' ]-value.

    UPDATE zovcab
       SET status = ld_status
     WHERE ordemid = ld_ordemid.

    IF sy-subrc = 0.
      CLEAR ls_bapiret2.
      ls_bapiret2-type    = 'S'.
      ls_bapiret2-message = 'Status atualizado'.
      APPEND ls_bapiret2 TO lt_bapiret2.
    ELSE.
      CLEAR ls_bapiret2.
      ls_bapiret2-type    = 'E'.
      ls_bapiret2-message = 'Erro ao atualizar status'.
      APPEND ls_bapiret2 TO lt_bapiret2.
    ENDIF.

  CALL METHOD me->copy_data_to_ref
    EXPORTING
      is_data = lt_bapiret2
    CHANGING
      cr_data = er_data.

  ENDIF.

  IF iv_action_name = 'ZFI_ATUALIZA_STATUS_COMPLX'.
    ld_ordemid = it_parameter[ name = 'ID_ORDEMID' ]-value.
    ld_status  = it_parameter[ name = 'ID_STATUS' ]-value.

    UPDATE zovcab
       SET status = ld_status
     WHERE ordemid = ld_ordemid.

    IF sy-subrc = 0.
      CLEAR ls_bapiret2.
      ls_bapiret22-tIPO    = 'S'.
      ls_bapiret22-mENSAGEM = 'Status atualizado - CMPLX'.
      APPEND ls_bapiret22 TO lt_bapiret22.
    ELSE.
      CLEAR ls_bapiret2.
      ls_bapiret22-tIPO    = 'E'.
      ls_bapiret22-mENSAGEM = 'Erro ao atualizar status - CMPLX'.
      APPEND ls_bapiret22 TO lt_bapiret22.
    ENDIF.

  CALL METHOD me->copy_data_to_ref
    EXPORTING
      is_data = lt_bapiret22
    CHANGING
      cr_data = er_data.

  ENDIF.

 ENDMETHOD.


  method OVCABSET_DELETE_ENTITY.
    DATA: ls_key_tab LIKE LINE OF it_key_tab.

    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.
    IF sy-subrc <> 0.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'OrdemId não informado'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.

    DELETE FROM zovitem_rj WHERE ordemid = ls_key_tab-value.
    " Vinicius 28/04/2024 - Comentando validação pois algumas ordens podem
    " não tem itens
*  IF sy-subrc <> 0.
*    ROLLBACK WORK.
*
*    lo_msg->add_message_text_only(
*      EXPORTING
*        iv_msg_type = 'E'
*        iv_msg_text = 'Erro ao remover itens'
*    ).
*
*    RAISE EXCEPTION type /iwbep/cx_mgw_busi_exception
*      EXPORTING
*        message_container = lo_msg.
*  ENDIF.

    DELETE FROM zovcab_rj WHERE ordemid = ls_key_tab-value.
    IF sy-subrc <> 0.
      ROLLBACK WORK.

      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao remover ordem'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.

    COMMIT WORK AND WAIT.
  endmethod.


  METHOD ovitemset_delete_entity.
    DATA: ls_item    TYPE zovitem.
    DATA: ls_key_tab LIKE LINE OF it_key_tab.

    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    ls_item-ordemid = it_key_tab[ name = 'OrdemId' ]-value.
    ls_item-itemid  = it_key_tab[ name = 'ItemId' ]-value.

    DELETE FROM zovitem_aline
     WHERE ordemid = ls_item-ordemid
       AND itemid  = ls_item-itemid.
    IF sy-subrc <> 0.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao remover item'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
