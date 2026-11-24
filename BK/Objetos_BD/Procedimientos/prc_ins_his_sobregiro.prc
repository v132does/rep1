create or replace procedure it.PRC_INS_HIS_SOBREGIRO(P_NRO_SECUENCIA IN NUMBER,
                                                  P_CAN_AUTOMATICA IN VARCHAR2 DEFAULT 'N') is
  v_estado cc_lin_sobregiros.estado%type;
  v_observ cc_lin_sobregiros.observacion%type;
  v_usuaut cc_lin_sobregiros.cod_usu_autoriza%type;
  v_nivel  cc_lin_sobregiros.niv_aprobacion%type;
BEGIN
   Select estado, observacion, niv_aprobacion, cod_usu_autoriza
     into v_estado, v_observ, v_nivel, v_usuaut
     from cc_lin_sobregiros
    where nro_secuencia = p_nro_secuencia;
   --
   UPDATE CC_LIN_SOBREGIROS C
      SET ESTADO = v_estado,
          OBSERVACION = v_observ,
          COD_USU_AUTORIZA = v_usuaut,
          NIV_APROBACION = v_nivel
    WHERE C.NRO_SEC_PADRE = P_NRO_SECUENCIA;

   INSERT INTO CC_LIN_SOBREGIROS_HIS(COD_USU_AUTORIZA,NRO_CUENTA,FEC_VENCIMIENTO,
               COD_TASA,VAL_TAS_INTERES,DIA_TASA,TAS_PREFERENCIAL,DIA_SIN_COSTO,
               NRO_LINEA,FEC_INICIO,NRO_SECUENCIA,MONTO,TIPO,COD_PERSONA,COD_MONEDA,ESTADO,
               NRO_SEC_PADRE,OBSERVACION,NIV_APROBACION,CAN_AUTOMATICA,COD_CANAL,COD_CAMPANA, COD_RUB_ECONOMICO)
       (SELECT COD_USU_AUTORIZA,NRO_CUENTA,FEC_VENCIMIENTO,
               COD_TASA,VAL_TAS_INTERES,DIA_TASA,TAS_PREFERENCIAL,DIA_SIN_COSTO,
               NRO_LINEA,FEC_INICIO,NRO_SECUENCIA,MONTO,TIPO,COD_PERSONA,COD_MONEDA,ESTADO,
               NRO_SEC_PADRE,OBSERVACION,NIV_APROBACION,NVL(P_CAN_AUTOMATICA,'N'),COD_CANAL,COD_CAMPANA, COD_RUB_ECONOMICO
          FROM CC_LIN_SOBREGIROS
         WHERE NRO_SECUENCIA = P_NRO_SECUENCIA
            OR NRO_SEC_PADRE = P_NRO_SECUENCIA);

   INSERT INTO CC_LIN_SOB_GARANTIAS_HIS(MTO_APLICADO,NRO_GARANTIA,NRO_SECUENCIA,COD_GARANTIA)
       (SELECT MTO_APLICADO,NRO_GARANTIA,NRO_SECUENCIA,COD_GARANTIA
          FROM CC_LIN_SOB_GARANTIAS
         WHERE NRO_SECUENCIA = P_NRO_SECUENCIA);
EXCEPTION
  when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000, 'Error al insertar historico de sobregiro: '||p_nro_secuencia||' '||sqlerrm);
      end if;
end PRC_INS_HIS_SOBREGIRO;
/

