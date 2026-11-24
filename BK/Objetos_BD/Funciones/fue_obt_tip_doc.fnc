create or replace function it.FUE_OBT_TIP_DOC
 (P_COD_PERSONA VARCHAR2
 )
 RETURN VARCHAR2 IS
 v_detalle_1 varchar2(1000);
 v_detalle_3 varchar2(1000);
 v_detalle_4 varchar2(3);
 Begin
  --ESTA FUNCION RECUPERA EL TIPO DE DOCUMENTO ANTERIOR DE LA TABLA DE BA_AUDITORIA

  -- seleccionamos de Ba_auditorias  si se modificó el tipo doc
  SELECT TRIM(Detalle)
  into v_detalle_1
  from BA_auditorias
  where tabla='BA_PERSONAS' AND TIP_NOVEDAD = 'M' AND
  ORIGEN='ERREPERS' AND trim(clave)=trim(P_COD_PERSONA)
  and (DETALLE LIKE '%COD_TIP_DOCUMENTO%')
  and rownum < 2
  order by  fec_sistema desc ;

      v_detalle_3:=
      trim(substr(
      substr(FUE_OBT_NOVEDAD('M', v_detalle_1),
      instr(FUE_OBT_NOVEDAD('M',v_detalle_1)
      ,'Cod. Tip. Documento:' )+20,7),1,
      instr(
      substr(FUE_OBT_NOVEDAD('M', v_detalle_1),
      instr(FUE_OBT_NOVEDAD('M', v_detalle_1)
      ,'Cod. Tip. Documento:' )+20,7)
      ,'=>')-1));
   --Aquì se formatea el tipo de documento acorde al nuevo formato
   select
   case trim(abreviatura) when 'CI' THEN 'CIP'
   when null then NULL
   ELSE  trim(abreviatura) ENd
   into v_detalle_4
   from ba_tip_documentos
   where trim(cod_tip_documento)= trim(v_detalle_3);

RETURN V_DETALLE_4;

end FUE_OBT_TIP_DOC;
/

