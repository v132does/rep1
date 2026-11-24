CREATE OR REPLACE FUNCTION IT.FUS_SNP_OBT_PRIORIDAD(P_COD_MSJ_SWIFT     IN ge_snp_transferencias.cod_msj_swift%type,
                                                 P_TIP_OPERACION     IN ge_snp_par_mensajes.cod_tip_operacion%type,
                                                 P_SUB_TIP_OPERACION IN ge_snp_par_mensajes.cod_sub_tip_operacion%type)
  RETURN VARCHAR2 IS
  /*
  || Obtiene la prioridad configurada según el MT, Tipo, y SubTipo de Operación
  */
v_prioridad  ge_snp_transferencias.prioridad%type;
BEGIN
  BEGIN
    select m.prioridad
    into v_prioridad
    from ge_snp_par_mensajes m
   where m.cod_msj_swift = P_COD_MSJ_SWIFT
     and m.cod_tip_operacion = P_TIP_OPERACION
     and nvl(m.cod_sub_tip_operacion, 'x') = nvl(P_SUB_TIP_OPERACION, 'x');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    v_prioridad := NULL;
  WHEN OTHERS THEN
    v_prioridad := NULL;
  END;

  IF v_prioridad is NULL THEN
     IF P_COD_MSJ_SWIFT = 103 THEN
        v_prioridad := 20;
     ELSIF P_COD_MSJ_SWIFT = 102 THEN
      v_prioridad := 100;
     END IF;
  END IF;

  return v_prioridad;

EXCEPTION
  WHEN OTHERS THEN
  return v_prioridad;
END;
/

