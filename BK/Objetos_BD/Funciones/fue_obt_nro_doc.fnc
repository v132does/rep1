create or replace function it.FUE_OBT_NRO_DOC
 (P_COD_PERSONA VARCHAR2
 )
 RETURN VARCHAR2 IS
 v_detalle_1 varchar2(1000);
 v_detalle_3 varchar2(1000);

 Begin
 --ESTA FUNCION RECUPERA EL NRO DE DOCUMENTO ANTERIOR DE LA TABLA DE BA_AUDITORIAS--
  --Selecciono el detalle de lo que se modificó de la tabla ba_auditoria
  SELECT TRIM(Detalle)
  into v_detalle_1
  from BA_auditorias
  where tabla='BA_PERSONAS' AND TIP_NOVEDAD = 'M' AND
  ORIGEN='ERREPERS' AND trim(clave)=trim(P_COD_PERSONA)
  and (DETALLE LIKE '%NRO_DOCUMENTO%')
  and rownum < 2
  order by  fec_sistema desc ;

      --Le formateo de la funcion fue_obt_novedad
      v_detalle_3:=
      trim(substr(
      substr(FUE_OBT_NOVEDAD('M', trim(v_detalle_1)),
      instr(FUE_OBT_NOVEDAD('M',trim(v_detalle_1))
      ,'Nro. Documento:' )+16,20),1,
      instr(
      substr(FUE_OBT_NOVEDAD('M', trim(v_detalle_1)),
      instr(FUE_OBT_NOVEDAD('M', trim(v_detalle_1))
      ,'Nro. Documento:' )+16,20)
      ,'=>')-1));

RETURN V_DETALLE_3;
end FUE_OBT_NRO_DOC;
/

