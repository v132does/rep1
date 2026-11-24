CREATE OR REPLACE PROCEDURE IT.PRT_GEN_DAT_DEBCRE(p_cod_procesadora in varchar2)
 IS
   /*Definicion de variables utilizadas*/
   v_fec_actual          ge_calendarios.fec_actual%type;
   v_cod_gru_transaccion ge_gru_transacciones_det.cod_gru_transaccion%type;

   cursor movimientos is
   select mov.nro_cuenta,tar.nro_tarjeta,mov.fecha,mov.concepto,mov.monto,mov.nro_documento3,
          mov.cod_usuario,mov.cod_transaccion,mov.cod_modulo,mov.cod_modalidad,
          mov.nro_documento2
    from ge_movimientos mov,
         ge_gru_transacciones_det gru,
         ta_tarjetas tar
   where gru.cod_gru_transaccion = v_cod_gru_transaccion
     and gru.cod_transaccion     = mov.cod_transaccion
     and gru.cod_modulo          = mov.cod_modulo
     and gru.cod_modalidad       = mov.cod_modalidad
     and mov.fecha               = v_fec_actual
     and mov.nro_cuenta   is not null
     and mov.reversado = 'N'
     and mov.nro_cuenta = tar.nro_cuenta
     and fug_obt_cli_principal(tar.nro_cuenta) = tar.cod_persona 
     and tar.vigente = 'S'
     and mov.estado = 'N'
     and exists (select 1
                   from ta_tipos b
                  where b.cod_modulo = mov.cod_modulo
                    and b.cod_modalidad = mov.cod_modalidad
                    and b.cod_ent_procesadora = p_cod_procesadora);
-----*************** Cursor de tarjetas en mora DE-240 16/01/2015
 cursor c_tar_mora is 
	Select TT.NRO_TARJETA NRO_TARJETA,
       Sysdate FEC_VALOR,
       '**AJUSTE SALDO CR' CONCEPTO,
       TCT.COD_MONEDA COD_MONEDA,
       TCT.MTO_MORA,
       '33' TIP_CARGO,
       '3' TIP_SALDO,
       'C' TIP_TRAN,
       'S' FINANCIA,
       User COD_USUARIO,
       '?' IVA,
       'N' MOV_RES1,   
       CT.COD_PERSONA,
       CT.NRO_CUENTA,
       TCT.DIA_MORA     
  From TA_CTA_TARJETAS TCT,
       TA_TARJETAS     TT,
       GE_CTA_CLIENTES CT
 Where TCT.NRO_CUENTA = TT.NRO_CUENTA
   AND TCT.NRO_CUENTA = CT.NRO_CUENTA
   AND NVL(CT.RELACION,'X') = 'P'
   AND TT.COD_PERSONA = CT.COD_PERSONA
   /*AND TT.VIGENTE = 'S'*/ -- RE - Jira DE-240 23/06/2015, se comenta para que tome todas las tarjetas sin discriminar por estado, pedido de Claudia Villalba.
   And TCT.DIA_MORA >= FUG_OBT_PARDINAMICO('DIAS_MORA', '5')
   And TCT.MTO_MORA <= FUG_OBT_PARDINAMICO('MTO_MORA_TC', '5')
  AND TT.NRO_TARJETA = (Select max(tar.nro_tarjeta) from TA_TARJETAS TAR
                        where tar.nro_cuenta = tt.nro_cuenta
                          and tar.cod_persona = tt.cod_persona
                          group by tar.nro_cuenta);

BEGIN
   --inicio del prg principal--
   BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

   v_fec_actual          := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   --Obtener el grupo de tansacciones de impuestos
   v_cod_gru_transaccion := fug_obt_pardinamico('COD_GRU_ENV_DEBCRE');

   --borrar datos anteriores si hubiere--
   delete from ta_env_debcre
    where cod_ent_procesadora = p_cod_procesadora;

   --cursor principal--
   for r_cue in movimientos loop
      insert into ta_env_debcre
        (cod_ent_procesadora, nro_cuenta,nro_tarjeta, monto,fec_valor,
         fec_envio, hor_envio,concepto,cod_usuario,financia,cod_transaccion,cod_modulo,cod_modalidad,
         tip_saldo)
      values
        (p_cod_procesadora,r_cue.nro_cuenta, r_cue.nro_tarjeta, r_cue.monto, r_cue.fecha,
         null,null,r_cue.concepto,r_cue.cod_usuario,to_char(r_cue.nro_documento3),
         r_cue.cod_transaccion,r_cue.cod_modulo,r_cue.cod_modalidad,
         substr(to_char(r_cue.nro_documento2),1,3));
   end loop;
   
   --cursor de tarjetas en mora
   --borrar datos anteriores si hubiere--
   delete from ta_env_tar_mora_tmp
    where cod_procesadora = p_cod_procesadora;

   --cursor principal--
   for r_tar in c_tar_mora loop
      insert INTO ta_env_tar_mora_tmp
     ( NRO_TARJETA, FEC_VALOR,       CONCEPTO,    COD_MONEDA, 
       MTO_MORA,       TIP_CARGO,       TIP_SALDO,   TIP_TRAN, 
       FINANCIA,    COD_USUARIO,     IVA,         IMPUESTO_IVA, 
       MOV_RES1,    COD_PROCESADORA, COD_PERSONA, NRO_CUENTA,
       DIA_MORA)
      values
        (r_tar.nro_tarjeta, r_tar.fec_valor, r_tar.concepto, r_tar.cod_moneda,
         r_tar.mto_mora,r_tar.tip_cargo,r_tar.tip_saldo,r_tar.tip_tran,
         r_tar.financia,r_tar.cod_usuario,r_tar.iva,NULL,
         r_tar.mov_res1,p_cod_procesadora, r_tar.cod_persona, r_tar.nro_cuenta,
         r_tar.dia_mora);
   end loop;
exception
  when OTHERS Then
    RAISE_APPLICATION_ERROR(-20000,'Al procesar movimientos '||SQLERRM);
END;
/

