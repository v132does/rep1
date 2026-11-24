create or replace procedure                            it.prc_act_fac_electronica(Pjson in clob) is

v_fecha_emision date;
v_error varchar2(2000);
    v_id_documento NUMBER;    
/*cursor*/
cursor c_up_fact is
SELECT upper(ESTADO_LOTE)ESTADO_LOTE,
       TIPO_DOCUMENTO, NRO_DOCUMENTO,
       upper(ESTADO_FACTURA)ESTADO_FACTURA,
       COD_CONTROL,OBSERVACIONES
FROM
   it.CB_FE_TEMP_JSON D,
   JSON_TABLE
   (
     D.JSON_VALUE, '$' COLUMNS
     (
       ESTADO_LOTE VARCHAR2(20) PATH '$.estado',
       NESTED path '$.documentos[*]' COLUMNS
       (
         TIPO_DOCUMENTO NUMBER(1) PATH '$.tipo_documento',
         NRO_DOCUMENTO VARCHAR2(15) PATH '$.nro_documento',
         ESTADO_FACTURA VARCHAR2(100) PATH '$.estado',
         COD_CONTROL VARCHAR2(100) PATH '$.cdc',
         OBSERVACIONES VARCHAR2(4000) PATH '$.observaciones' --GP  TN-844 
       )
     )
 ) J
 ORDER BY tipo_documento;

/*Insertar el JSON recibido de la API de Factury a la tabla temporal*/
procedure lp_ins_tabla_temp is
  begin
      insert into it.CB_FE_TEMP_JSON values(Pjson);
end;

/*principal*/
begin

  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo :=1;
  lp_ins_tabla_temp;

  for reg in c_up_fact loop
    v_error := null;
    begin
      select distinct(c.dfeemide)
        into v_fecha_emision
        from cb_doc_elec_cab c
       WHERE DEST||'-'||DPUNEXP||'-'||DNUMDOC= REG.NRO_DOCUMENTO
         AND ITIDE = reg.TIPO_DOCUMENTO
         and c.est_fac='ENVIADO'
         and c.fec_insercion = (select max(t.fec_insercion)
                                  from cb_doc_elec_cab t
                                 where C.DEST||'-'||C.DPUNEXP||'-'||C.DNUMDOC= T.DEST||'-'||T.DPUNEXP||'-'||T.DNUMDOC
                                   AND C.ITIDE = T.ITIDE);
       exception
         when others then
           v_error := SQLERRM;
           INSERT INTO cb_log_doc_electronico a
               (a.id_documento, a.cod_usuario, a.fecha, a.hora, a.itide, a.dnumdoc, a.dcodcliente,
                a.cod_respuesta, a.msj_respuesta, a.det_xml, a.cod_error, a.msj_error)
           VALUES
               (1, user, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), reg.TIPO_DOCUMENTO, null, null,
                null, null, 'Error en prc_act_fac_electronica, con el documento '||REG.NRO_DOCUMENTO||'. '||v_error, null, 'Error_1');
    end;

    /*Sólo actualizar el CDC si el documento está aprobado por SIFEN*/
    if (reg.ESTADO_FACTURA='APROBADO' or reg.ESTADO_FACTURA='APROBADO CON OBSERVACIONES') then
      if reg.TIPO_DOCUMENTO = 1 then--Si el documento es factura
        begin
          UPDATE cb_lib_ventas
             SET cod_control =REG.COD_CONTROL
           WHERE NRO_FACTURA=REG.NRO_DOCUMENTO
             and fecha=v_fecha_emision
             and tip_comprobante='F';--Factura;
        exception
          when others then
            v_error := SQLERRM;
            INSERT INTO cb_log_doc_electronico a
                (a.id_documento, a.cod_usuario, a.fecha, a.hora, a.itide, a.dnumdoc, a.dcodcliente,
                 a.cod_respuesta, a.msj_respuesta, a.det_xml, a.cod_error, a.msj_error)
            VALUES
                (2, user, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), reg.TIPO_DOCUMENTO, null, null,
                 null, null, 'Error en prc_act_fac_electronica, al actualizar CB_LIB_VENTAS, numero de documento: '||REG.NRO_DOCUMENTO||'. '||v_error, null, 'Error_2');
        end;
      else
        if reg.TIPO_DOCUMENTO = 5 then--Si el documento es nota de crédito
          begin
            UPDATE cb_lib_ventas
               SET cod_control =REG.COD_CONTROL
             WHERE NRO_FACTURA=REG.NRO_DOCUMENTO
               and fecha=v_fecha_emision
               and tip_comprobante='N';--Nota de crédito;
          exception
           when others then
             v_error := SQLERRM;
             INSERT INTO cb_log_doc_electronico a
                 (a.id_documento, a.cod_usuario, a.fecha, a.hora, a.itide, a.dnumdoc, a.dcodcliente,
                  a.cod_respuesta, a.msj_respuesta, a.det_xml, a.cod_error, a.msj_error)
             VALUES
                 (3, user, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), reg.TIPO_DOCUMENTO, null, null,
                  null, null, 'Error en prc_act_fac_electronica, al actualizar CB_LIB_VENTAS, numero de documento: '||REG.NRO_DOCUMENTO||'. '||v_error, null, 'Error_3');
          end;
        end if;
      end if;

    elsif reg.ESTADO_FACTURA IN ('RECHAZADO', 'ERROR DE P') then --MJ-TN1018
      BEGIN
        SELECT ID_DOCUMENTO
        INTO v_id_documento
        FROM CB_DOC_ELEC_CAB
        WHERE DEST||'-'||DPUNEXP||'-'||DNUMDOC=REG.NRO_DOCUMENTO
           AND ITIDE = reg.TIPO_DOCUMENTO
           and est_fac='ENVIADO';
           
        INSERT INTO ge_log_errores
            (cod_programa,
             campo1,   dato1,
             campo2,   dato2,
             campo3,   dato3,
             det_error,
             usu_insercion,
             fec_insercion)
        VALUES
            ('PRC_ACT_FAC_ELECTRONICA',
             'NRO_FACTURA', reg.NRO_DOCUMENTO,
             'TIP_COMPROBANTE', decode(reg.TIPO_DOCUMENTO, 1, 'F', 5, 'N', null),
             'ID_DOCUMENTO',         v_id_documento,
             'Documento rechazado por SIFEN. Observaciones: ' || reg.OBSERVACIONES,
             'IT',
             sysdate);
      EXCEPTION
        WHEN OTHERS THEN
          v_error := SQLERRM;
          INSERT INTO cb_log_doc_electronico a
              (a.id_documento, a.cod_usuario, a.fecha, a.hora, a.itide, a.dnumdoc, a.dcodcliente,
               a.cod_respuesta, a.msj_respuesta, a.det_xml, a.cod_error, a.msj_error)
          VALUES
              (5, user, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), reg.TIPO_DOCUMENTO, null, null,
               null, null, 'Error al insertar en GE_LOG_ERRORES, documento: '||REG.NRO_DOCUMENTO||'. '||v_error, null, 'Error_5');
      end;
    end if;
    
    /*Actualizar el CDC, el estado y la observacion del documento*/
      begin
        UPDATE cb_doc_elec_cab
           SET cod_control =REG.COD_CONTROL,
               est_fac = substr(reg.ESTADO_FACTURA,1,10),
		       sfn_observaciones = reg.OBSERVACIONES --GP  TN-844
         WHERE DEST||'-'||DPUNEXP||'-'||DNUMDOC=REG.NRO_DOCUMENTO
           AND ITIDE = reg.TIPO_DOCUMENTO
           and est_fac='ENVIADO';
      exception
           when others then
             v_error := SQLERRM;
             INSERT INTO cb_log_doc_electronico a
                 (a.id_documento, a.cod_usuario, a.fecha, a.hora, a.itide, a.dnumdoc, a.dcodcliente,
                  a.cod_respuesta, a.msj_respuesta, a.det_xml, a.cod_error, a.msj_error)
             VALUES
                 (4, user, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), reg.TIPO_DOCUMENTO, null, null,
                  null, null, 'Error en prc_act_fac_electronica, al actualizar CB_DOC_ELEC_CAB, numero de documento: '||REG.NRO_DOCUMENTO||'. '||v_error, null, 'Error_4');
      end;

  end loop;
  COMMIT;
end;
