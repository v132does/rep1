CREATE OR REPLACE TRIGGER IT.MA_GE_MOV_TMP
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_MOV_TMP
 FOR EACH ROW

declare
  v_fec_modulo ge_calendarios.fec_actual%TYPE;
begin
   -- Registrar campos de migracion
   if inserting then

      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
      
      begin
        select f.fec_actual into v_fec_modulo
        from ge_calendarios f
        where f.cod_modulo = 14;
      EXCEPTION
         WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20000,'Error al obtener fecha modulo de ITGF: '||sqlerrm);
      end;
      
      insert
      into GE_MOVIMIENTOS
            (
            FECHA,
            HORA,
            COD_USUARIO,
            NRO_SECUENCIA,
            FEC_VALOR,
            MONTO,
            NRO_CUENTA,
            COD_MONEDA,
            COD_OFICINA,
            COD_ERROR,
            COD_RETENCION,
            FEC_FIN_RETENCION,
            EST_CUENTA,
            ESTADO,
            COD_CAUSA,
            COD_BANCO,
            COD_OFI_ORIGEN,
            CONCEPTO,
            COD_TASA,
            VAL_TASA,
            COD_RUBRO,
            COD_REF_CAMBIO,
            REVERSADO,
            COD_USU_REVERSION,
            HOR_REVERSION,
            EMI_AVISO,
            COD_TRA_PADRE,
            COD_MOD_PADRE,
            COD_MAD_PADRE,
            COD_TRANSACCION,
            COD_MODULO,
            COD_MODALIDAD,
            MTO_EQU_LOCAL,
            NRO_CAJA,
            COTIZACION,
            COD_BCO_CENTRAL,
            NRO_DOCUMENTO,
            NRO_DOCUMENTO2,
            NRO_DOCUMENTO3,
            NRO_DOCUMENTO4,
            PROTEGIDO,
            COD_AUTORIZACION,
            COD_USU_AUTORIZADOR,
            USU_INSERCION,
            --FEC_INSERCION,
            USU_MODIFICACION,
            --FEC_MODIFICACION,
            TIP_MOV_RUBRO,
            COD_TIP_OPE_CAMBIO,
            REFERENCIA
            )
       values
           (
           v_fec_modulo,
           :new.HORA,
           :new.COD_USUARIO,
           :new.NRO_SECUENCIA,
           :new.FEC_VALOR,
           :new.MONTO,
           :new.NRO_CUENTA,
           :new.COD_MONEDA,
           :new.COD_OFICINA,
           :new.COD_ERROR,
           :new.COD_RETENCION,
           :new.FEC_FIN_RETENCION,
           :new.EST_CUENTA,
           :new.ESTADO,
           :new.COD_CAUSA,
           :new.COD_BANCO,
           :new.COD_OFI_ORIGEN,
           :new.CONCEPTO,
           :new.COD_TASA,
           :new.VAL_TASA,
           :new.COD_RUBRO,
           :new.COD_REF_CAMBIO,
           :new.REVERSADO,
           :new.COD_USU_REVERSION,
           :new.HOR_REVERSION,
           :new.EMI_AVISO,
           :new.COD_TRA_PADRE,
           :new.COD_MOD_PADRE,
           :new.COD_MAD_PADRE,
           :new.COD_TRANSACCION,
           :new.COD_MODULO,
           :new.COD_MODALIDAD,
           :new.MTO_EQU_LOCAL,
           :new.NRO_CAJA,
           :new.COTIZACION,
           :new.COD_BCO_CENTRAL,
           :new.NRO_DOCUMENTO,
           :new.NRO_DOCUMENTO2,
           :new.NRO_DOCUMENTO3,
           :new.NRO_DOCUMENTO4,
           :new.PROTEGIDO,
           :new.COD_AUTORIZACION,
           :new.COD_USU_AUTORIZADOR,
           :new.USU_INSERCION,
           --:new.FEC_INSERCION,
           :new.USU_MODIFICACION,
           --:new.FEC_MODIFICACION,
           :new.TIP_MOV_RUBRO,
           :new.COD_TIP_OPE_CAMBIO,
           :new.REFERENCIA
           );

   end if;
   
EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al insertar movimiento en ITGF: '||sqlerrm);
END;
/

