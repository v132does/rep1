CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_EXT_TMP is
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_msj  varchar2(500);
  v_fecha           date := pag_cal.fu_obt_fec_actual(1);  
  v_hor_inicio      varchar2(8);
  v_hor_fin         varchar2(8);  
  
  --Ref: DESOPIMI-20 - Mejora de Envio de Extracto por Mails--
  procedure pr_tru_tab_temporales is
   begin
     v_msj := null;
     sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_ASCII_TMP', v_msj);
     if v_msj is not null then
        raise_application_error(-20000, v_msj);
     end if;
     v_msj := null;
     sql_util.ejecute_dml('TRUNCATE TABLE GE_MOV_MENSUAL', v_msj);
     if v_msj is not null then
        raise_application_error(-20000, v_msj);
     end if;
  end pr_tru_tab_temporales;

  procedure pr_eli_ext_generado is
   begin
    -- Borra los extractos generados x el usuario,para no dejar basura
      DELETE FROM GE_EXT_CLI_MOVIMIENTOS_TMP
       WHERE USU_INSERCION = USER;
      DELETE FROM GE_EXT_RESUMENES_TMP
       WHERE USU_INSERCION = USER;
      DELETE FROM GE_EXT_CLI_CUENTAS_TMP
       WHERE USU_INSERCION = USER;
      DELETE FROM GE_EXT_CLIENTES_TMP
       WHERE USU_INSERCION = USER;
      DELETE ge_ext_cli_mov_retenidos_tmp
       WHERE USU_INSERCION = USER;
      DELETE ge_ext_cli_mov_pendientes
       WHERE USU_INSERCION = USER;
      -- Borra los extractos generados x cliente
      DELETE FROM GE_EXT_CLI_MOVIMIENTOS_TMP x
       WHERE EXISTS (select 1 from GE_EXT_ASCII_TMP z
                      where z.cod_persona = x.cod_persona);
      DELETE FROM GE_EXT_RESUMENES_TMP x
       WHERE EXISTS (select 1 from GE_EXT_ASCII_TMP z
                      where z.cod_persona = x.cod_persona);
      DELETE FROM GE_EXT_CLI_CUENTAS_TMP x
       WHERE EXISTS (select 1 from GE_EXT_ASCII_TMP z
                      where z.cod_persona = x.cod_persona);
      DELETE FROM GE_EXT_CLIENTES_TMP x
       WHERE EXISTS (select 1 from GE_EXT_ASCII_TMP z
                      where z.cod_persona = x.cod_persona);
      DELETE ge_ext_cli_mov_retenidos_tmp x
       WHERE EXISTS (select 1 from GE_EXT_ASCII_TMP z
                      where z.cod_persona = x.cod_persona);
      DELETE ge_ext_cli_mov_pendientes x
       WHERE EXISTS (select 1 from GE_EXT_ASCII_TMP z
                      where z.cod_persona = x.cod_persona);
   end pr_eli_ext_generado;

   procedure pr_ins_mov_ahorros is
   begin
    --Insercion de Movimeintos de Ahorros--
    insert into ge_mov_mensual
    (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, nro_cuenta, cod_moneda, cod_oficina,
     cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco, cod_ofi_origen,
     concepto, cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
     emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad,
     mto_equ_local, nro_caja, cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
     nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador, usu_insercion, fec_insercion,
     usu_modificacion, fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, nro_folio, referencia,
     cod_persona, cod_sit_contable, nro_conciliacion)
    select
     fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, x.nro_cuenta, x.cod_moneda, x.cod_oficina,
     cod_error, x.cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco, cod_ofi_origen,
     concepto, x.cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
     emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre, x.cod_transaccion, x.cod_modulo, x.cod_modalidad,
     mto_equ_local, nro_caja, cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
     nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador, x.usu_insercion, x.fec_insercion,
     x.usu_modificacion, x.fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, nro_folio, referencia,
     x.cod_persona, cod_sit_contable, nro_conciliacion
    from ah_movimientos_his x, ge_ext_ascii_tmp z, GE_TRANSACCIONES y
    where z.nro_cuenta = x.nro_cuenta
      and x.fecha > z.fec_ult_extracto
      and x.fecha <= v_fec_actual
      and (x.REVERSADO = 'N' OR
          (x.REVERSADO = 'S' AND
           FEC_VALOR <= z.FEC_ULT_EXTRACTO   AND
           EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                    WHERE x.FEC_VALOR = REV.FECHA
                      AND x.HOR_REVERSION  = REV.HORA
                      AND x.COD_USU_REVERSION = REV.COD_USUARIO
                      AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                      -- DYDMR-5672 NAF 01/2017
                      AND x.NRO_CUENTA = REV.NRO_CUENTA
                      AND abs(x.MONTO) = abs(REV.MONTO)
                   )) OR
          (x.REVERSADO = 'S' AND x.COD_TRA_PADRE in (303, 302) AND x.Cod_Mad_Padre = 455))
       AND x.ESTADO = 'N'
       AND x.NRO_FOLIO IS NULL
       AND x.COD_MODULO = y.COD_MODULO
       AND x.COD_MODALIDAD = y.COD_MODALIDAD
       AND x.COD_TRANSACCION = y.COD_TRANSACCION
       AND y.VE_CLIENTE = 'S'
       AND NVL(y.AFECTA,'XX') != 'B'
       AND y.TIPO IN ('C','D');
  end pr_ins_mov_ahorros;

  procedure pr_ins_mov_ctacte is
   begin
    --Insercion de Movimeintos de Ahorros--
    insert into ge_mov_mensual
    (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, nro_cuenta, cod_moneda, cod_oficina,
     cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco, cod_ofi_origen,
     concepto, cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
     emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad,
     mto_equ_local, nro_caja, cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
     nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador, usu_insercion, fec_insercion,
     usu_modificacion, fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, nro_folio, referencia,
     cod_persona, cod_sit_contable, nro_conciliacion)
    select
     fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, x.nro_cuenta, x.cod_moneda, x.cod_oficina,
     cod_error, x.cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco, cod_ofi_origen,
     concepto, x.cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
     emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre, x.cod_transaccion, x.cod_modulo, x.cod_modalidad,
     mto_equ_local, nro_caja, cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
     nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador, x.usu_insercion, x.fec_insercion,
     x.usu_modificacion, x.fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, nro_folio, referencia,
     x.cod_persona, cod_sit_contable, nro_conciliacion
    from cc_movimientos_his x, ge_ext_ascii_tmp z, GE_TRANSACCIONES y
    where z.nro_cuenta = x.nro_cuenta
      and x.fecha > z.fec_ult_extracto
      and x.fecha <= v_fec_actual
      and (x.REVERSADO = 'N' OR
          (x.REVERSADO = 'S' AND
           FEC_VALOR <= z.FEC_ULT_EXTRACTO   AND
           EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                    WHERE x.FEC_VALOR = REV.FECHA
                      AND x.HOR_REVERSION  = REV.HORA
                      AND x.COD_USU_REVERSION = REV.COD_USUARIO
                      AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                      -- DYDMR-5672 NAF 01/2017
                      AND x.NRO_CUENTA = REV.NRO_CUENTA
                      AND abs(x.MONTO) = abs(REV.MONTO)
                   )) OR
          (x.REVERSADO = 'S' AND x.COD_TRA_PADRE in (303, 302) AND x.Cod_Mad_Padre = 455))
       AND x.ESTADO = 'N'
       AND x.NRO_FOLIO IS NULL
       AND x.COD_MODULO = y.COD_MODULO
       AND x.COD_MODALIDAD = y.COD_MODALIDAD
       AND x.COD_TRANSACCION = y.COD_TRANSACCION
       AND y.VE_CLIENTE = 'S'
       AND NVL(y.AFECTA,'XX') != 'B'
       AND y.TIPO IN ('C','D');
  end pr_ins_mov_ctacte;

  procedure pr_ins_tab_tmp_ascii is
   begin
     INSERT INTO GE_EXT_ASCII_TMP
      (COD_PERSONA, NRO_CUENTA, MAIL, FORMATO, FRE_EXTRACTO, FRE_EXT_ASCII, FEC_ULT_EXTRACTO,
       COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, SAL_ULT_EXTRACTO, EXT_SEPARADO,
       COD_PAQUETE, COD_EXTRACTO)
      select a.cod_persona, a.nro_cuenta, replace(d.val_parametro,' ','') mail,
               fug_obt_paradicional(a.nro_cuenta,'EMAIL_FOR_ESPECIAL') formato, e.fre_extracto,
               fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') fre_ext_ascii, e.fec_ult_extracto,
               e.COD_MODULO, e.COD_MODALIDAD, e.COD_OFICINA, e.COD_MONEDA, e.sal_ult_extracto,
               DECODE(f.NRO_CUENTA, NULL, 'N', 'S') EXT_SEPARADO,
               NVL(g.COD_PAQUETE,0) COD_PAQUETE, 1
          from ge_cta_clientes a, ge_cta_dat_adicionales d, cc_cta_corrientes e,
               ge_dir_envios f, ge_paq_cuentas g
         where a.nro_cuenta = d.nro_cuenta
           and d.parametro = 'EMAIL_ENVIO_EXT_ASCII'
           and a.cod_modulo = 4
           and a.cod_modalidad = 41
           and a.relacion = 'P'
           and e.estado <> 'C'
           and e.nro_cuenta = a.nro_cuenta
           and f.cod_persona (+) = a.cod_persona
           and f.nro_cuenta (+)  = a.nro_cuenta
           and g.nro_cuenta(+) = a.nro_cuenta
           and g.cod_persona(+) = a.cod_persona
        union
        select a.cod_persona, a.nro_cuenta, replace(d.val_parametro,' ','') mail,
               fug_obt_paradicional(a.nro_cuenta,'EMAIL_FOR_ESPECIAL') formato, e.fre_extracto,
               fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') fre_ext_ascii, e.fec_ult_extracto,
               e.COD_MODULO, e.COD_MODALIDAD, e.COD_OFICINA, e.COD_MONEDA, e.sal_ult_extracto,
               DECODE(f.NRO_CUENTA, NULL, 'N', 'S') EXT_SEPARADO,
               NVL(g.COD_PAQUETE,0) COD_PAQUETE, 1
          from ge_cta_clientes a, ge_cta_dat_adicionales d, ah_cta_vistas e,
               ge_dir_envios f, ge_paq_cuentas g
         where a.nro_cuenta = d.nro_cuenta
           and d.parametro = 'EMAIL_ENVIO_EXT_ASCII'
           and a.cod_modulo = 3
           and a.cod_modalidad = 31
           and a.relacion = 'P'
           and e.estado <> 'C'
           and e.nro_cuenta = a.nro_cuenta
           and f.cod_persona (+) = a.cod_persona
           and f.nro_cuenta (+)  = a.nro_cuenta
           and g.nro_cuenta(+) = a.nro_cuenta
           and g.cod_persona(+) = a.cod_persona;
  end pr_ins_tab_tmp_ascii;

  procedure pr_act_dat_cod_extracto is
   --Variables Locales--
   v_cod_persona ba_personas.cod_persona%type;
   v_cod_extracto ge_paq_cuentas.nro_cuenta%type;
   v_can_juntos number;

   --Cursores--
   cursor c_clientes is
          select distinct p.cod_persona
            from GE_EXT_ASCII_TMP p
           group by p.cod_persona;

   cursor c_cuentas is
          select p.cod_persona, p.nro_cuenta, p.ext_separado, p.cod_paquete
            from GE_EXT_ASCII_TMP p
           where p.cod_persona = v_cod_persona;
   begin
     for cli in c_clientes loop
         v_cod_persona := cli.cod_persona;
         v_cod_extracto := 1;
         v_can_juntos := 0;
         for cue in c_cuentas loop
             if ((cue.ext_separado = 'S') or (cue.cod_paquete > 0)) then
                 v_cod_extracto := nvl(v_cod_extracto,0) + 1;
                 update GE_EXT_ASCII_TMP z
                    set z.cod_extracto = v_cod_extracto
                  where z.cod_persona = v_cod_persona
                    and z.nro_cuenta = cue.nro_cuenta;
             else
                 v_can_juntos := nvl(v_can_juntos,0) + 1;
             end if;
         end loop;
         if nvl(v_can_juntos,0) = 0 then
            update GE_EXT_ASCII_TMP z
               set z.cod_extracto = nvl(z.cod_extracto,0) - 1
             where z.cod_persona = v_cod_persona;
         end if;
     end loop;
  end pr_act_dat_cod_extracto;

  procedure pr_ins_mov_ext_det_ctacte is
   begin
     INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
               SELECT  cc.cod_persona, v_fec_actual,
                       GE_MOV_MENSUAL.FECHA, GE_MOV_MENSUAL.FEC_VALOR, GE_MOV_MENSUAL.HORA, GE_MOV_MENSUAL.NRO_CUENTA,
                       GE_MOV_MENSUAL.NRO_DOCUMENTO, GE_MOV_MENSUAL.COD_MOD_PADRE, GE_MOV_MENSUAL.COD_MAD_PADRE, GE_MOV_MENSUAL.COD_TRA_PADRE,
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                          NVL(GE_MOV_MENSUAL.MONTO,0),
                          0),
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOV_MENSUAL.MONTO,0),
                           0),
                       CC.COD_EXTRACTO, 'D' , GE_MOV_MENSUAL.NRO_SECUENCIA, GE_MOV_MENSUAL.cod_ofi_origen, GE_MOV_MENSUAL.fec_insercion
                 FROM GE_TRANSACCIONES, GE_MOV_MENSUAL, GE_EXT_ASCII_TMP cc
               WHERE GE_MOV_MENSUAL.NRO_CUENTA = cc.NRO_CUENTA
                 AND GE_MOV_MENSUAL.FECHA > cc.FEC_ULT_EXTRACTO
                 AND GE_MOV_MENSUAL.FECHA <= v_fec_actual
                 AND(GE_MOV_MENSUAL.REVERSADO = 'N' OR
                    (GE_MOV_MENSUAL.REVERSADO = 'S' AND
                     FEC_VALOR <= CC.FEC_ULT_EXTRACTO   AND
                     EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV
                              WHERE GE_MOV_MENSUAL.FEC_VALOR = REV.FECHA
                                AND GE_MOV_MENSUAL.HOR_REVERSION  = REV.HORA
                                AND GE_MOV_MENSUAL.COD_USU_REVERSION = REV.COD_USUARIO
                                AND GE_MOV_MENSUAL.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                -- DYDMR-5672 NAF 01/2017
                                AND GE_MOV_MENSUAL.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(GE_MOV_MENSUAL.MONTO) = abs(REV.MONTO)
                           )) OR
                     (GE_MOV_MENSUAL.REVERSADO = 'S' AND GE_MOV_MENSUAL.COD_TRA_PADRE in (303, 302)
                      AND GE_MOV_MENSUAL.Cod_Mad_Padre = 455))
                 AND GE_MOV_MENSUAL.ESTADO = 'N'
                 AND GE_MOV_MENSUAL.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND GE_MOV_MENSUAL.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND GE_MOV_MENSUAL.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND GE_MOV_MENSUAL.NRO_FOLIO IS NULL
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D')
                 AND CC.COD_MODULO = 4;
  end pr_ins_mov_ext_det_ctacte;

  procedure pr_ins_mov_ext_det_ahovista is
   begin
      INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, fec_insercion)
               SELECT  av.cod_persona, v_fec_actual,
                       GE_MOV_MENSUAL.FECHA, GE_MOV_MENSUAL.FEC_VALOR, GE_MOV_MENSUAL.HORA, GE_MOV_MENSUAL.NRO_CUENTA,
                       GE_MOV_MENSUAL.NRO_DOCUMENTO, GE_MOV_MENSUAL.COD_MOD_PADRE, GE_MOV_MENSUAL.COD_MAD_PADRE, GE_MOV_MENSUAL.COD_TRA_PADRE,
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(GE_MOV_MENSUAL.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOV_MENSUAL.MONTO,0),
                           0),
                      AV.COD_EXTRACTO, 'D', GE_MOV_MENSUAL.NRO_SECUENCIA, GE_MOV_MENSUAL.cod_ofi_origen, GE_MOV_MENSUAL.fec_insercion
                 FROM GE_TRANSACCIONES, GE_MOV_MENSUAL, GE_EXT_ASCII_TMP av
               WHERE GE_MOV_MENSUAL.NRO_CUENTA = av.NRO_CUENTA
                 AND GE_MOV_MENSUAL.FECHA > av.FEC_ULT_EXTRACTO
                 AND GE_MOV_MENSUAL.FECHA <= v_fec_actual
                 AND(GE_MOV_MENSUAL.REVERSADO = 'N' OR
                    (GE_MOV_MENSUAL.REVERSADO = 'S' AND
                     FEC_VALOR <= av.FEC_ULT_EXTRACTO   AND
                     EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV
                              WHERE GE_MOV_MENSUAL.FEC_VALOR = REV.FECHA
                                AND GE_MOV_MENSUAL.HOR_REVERSION  = REV.HORA
                                AND GE_MOV_MENSUAL.COD_USU_REVERSION = REV.COD_USUARIO
                                AND GE_MOV_MENSUAL.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                -- DYDMR-5672 NAF 01/2017
                                AND GE_MOV_MENSUAL.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(GE_MOV_MENSUAL.MONTO) = abs(REV.MONTO)
                           )) OR
                     (GE_MOV_MENSUAL.REVERSADO = 'S' AND GE_MOV_MENSUAL.COD_TRA_PADRE in (303, 302)
                      AND GE_MOV_MENSUAL.Cod_Mad_Padre = 455))
                 AND GE_MOV_MENSUAL.ESTADO = 'N'
                 AND GE_MOV_MENSUAL.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND GE_MOV_MENSUAL.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND GE_MOV_MENSUAL.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND GE_MOV_MENSUAL.NRO_FOLIO IS NULL
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D')
                 AND av.COD_MODULO = 3;                 
  end pr_ins_mov_ext_det_ahovista;
  
  
       
          
   

  procedure pr_ins_cli_ext_temporal is
   begin
     INSERT INTO GE_EXT_CLIENTES_TMP (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO,
                                    FUNCIONARIO, NOM_CLIENTE, DIRECCION,
                                    TELEFONO, COD_USU_OFICIAL, COD_PAIS,
                                    COD_CIUDAD, TEL_OFICIAL, NRO_INTERNO,
                                    COD_EXTRACTO, DET_DIRECCION, OBSERVACION,
                                    BARRIO, COD_MENSAJE, tip_impresion,
                                    CLI_CONFIDENCIAL, COD_OFICINA,
                                    Cat_Riesgo,Fec_Ult_Clasif )

                           /* VALUES (v_cod_persona, v_fec_actual,
                                    v_fre_extracto,v_es_empleado,
                                    v_nom_cliente, v_dir_cliente,
                                    v_tel_cliente, v_cod_usu_oficial,
                                    v_cod_pais, v_cod_ciudad,
                                    v_tel_oficial, v_int_oficial,v_cod_extracto,
                                    v_pri_obs_dir, v_seg_obs_dir,
                                    v_des_barrio, '1', v_imprime_extracto,
                                    v_cli_confidencial, decode(cc.SEPARADO,'S',cc.cod_oficina,v_cod_ofi_cliente),
                                    v_cat_riesgo, v_fec_ult_clasif);*/

             SELECT ba_personas.cod_persona, v_fec_actual,
             'D', FUG_ES_EMPLEADO(ba_personas.cod_persona),
             nom_completo, null,
             null, ge_clientes.cod_usu_oficial,
             null, null,
             ba_USUARIOS.TELEFONO, BA_USUARIOS.NRO_INTERNO, z.cod_extracto,
             null, null,
             null, '1', null,
             ge_clientes.cli_confidencial, ge_clientes.cod_oficina,
             pap_cat.fu_obt_cat_crc(ba_personas.cod_persona, v_fec_actual, 'N'), ge_clientes.fec_ult_clasif

             /*ge_clientes.cod_usu_oficial, ba_USUARIOS.TELEFONO,
             BA_USUARIOS.NRO_INTERNO, ge_clientes.tip_extracto,
             ge_clientes.cod_oficina, ge_clientes.cli_confidencial, nom_completo,
             pap_cat.fu_obt_cat_crc(v_cod_persona, v_fec_actual, 'N'), ge_clientes.fec_ult_clasif*/
        /*into v_cod_usu_oficial, v_tel_oficial, v_int_oficial, v_tip_extracto,
             v_cod_ofi_cliente, v_cli_confidencial, v_nom_cliente,
             v_cat_riesgo, v_fec_ult_clasif*/
        FROM BA_PERSONAS, BA_OFICINAS, BA_USUARIOS, GE_CLIENTES,
        (select distinct p.cod_persona, p.cod_extracto
           from GE_EXT_ASCII_TMP p) z
       WHERE BA_USUARIOS.COD_USUARIO = GE_CLIENTES.COD_USU_OFICIAL
         AND BA_OFICINAS.COD_OFICINA = BA_USUARIOS.COD_OFICINA
         AND GE_CLIENTES.COD_PERSONA = BA_PERSONAS.COD_PERSONA
         and exists (select 1 from GE_EXT_ASCII_TMP x
                     where x.cod_persona = ba_personas.cod_persona)
         and exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP y
                     where y.cod_persona = ba_personas.cod_persona
                       and y.usu_insercion = user)
         and z.cod_persona = ba_personas.cod_persona;
  end pr_ins_cli_ext_temporal;

  procedure pr_ins_cue_ext_temporal is
   begin
      INSERT INTO GE_EXT_CLI_CUENTAS_TMP
      (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
       GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
       GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,
       GE_EXT_CLI_CUENTAS_TMP.NRO_FOLIO, GE_EXT_CLI_CUENTAS_TMP.SAL_A_CONFIRMAR, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO,
       GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, sal_promedio, nro_cta_combinada, Tas_Nominal, Tas_Efectiva, cod_modulo,
       GE_EXT_CLI_CUENTAS_TMP.SAL_BLOQUEADO, SAL_BLO_ANTERIOR)
       select x.cod_persona, v_fec_actual, 'A',
              x.cod_oficina, x.cod_modalidad, x.nro_cuenta,
              x.cod_moneda, x.sal_ult_extracto,
       NVL(x.sal_ult_extracto,0) + NVL(k.mto_credito,0) - NVL(k.mto_debito,0),
       null /*cc.NRO_FOLIO*/, 0 /*cc.SAL_RETENIDO*/, x.cod_extracto,
       'D', 0 /*v_sal_promedio*/, null /*v_nro_cta_combinada*/, 0 /*v_val_tasa*/, 0 /*v_val_tae*/,
       x.COD_MODULO, 0 /*v_mto_bloqueo*/, 0 /*v_sal_blo_anterior*/
         from GE_EXT_ASCII_TMP x,
         (select k.nro_cuenta,
                 sum(nvl(k.mto_credito,0)) mto_credito,
                 sum(nvl(k.mto_debito,0)) mto_debito
            from GE_EXT_CLI_MOVIMIENTOS_TMP k
           where k.usu_insercion = user
           group by k.nro_cuenta) k
        where k.nro_cuenta = x.nro_cuenta;
  end;

  procedure lp_mar_ext_con_diferencia is
    --Cursor de Cuentas con diferencia para ahorros vistas y Cta. Corrientes--
    CURSOR DIFEREN IS
       SELECT GE_EXT_CLIENTES_TMP.COD_PERSONA, GE_EXT_CLIENTES_TMP.COD_EXTRACTO, GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
         FROM GE_EXT_CLIENTES_TMP
        WHERE GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual
          AND EXISTS (SELECT 0
                        FROM AH_CTA_VISTAS, GE_EXT_CLI_CUENTAS_TMP
                       WHERE AH_CTA_VISTAS.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA
                         AND AH_CTA_VISTAS.COD_MODALIDAD = GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD
                         AND AH_CTA_VISTAS.COD_OFICINA = GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA = GE_EXT_CLIENTES_TMP.COD_PERSONA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO = GE_EXT_CLIENTES_TMP.COD_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO = GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO = GE_EXT_CLIENTES_TMP.FRE_EXTRACTO
                         AND AH_CTA_VISTAS.COD_MODULO = 3
                         AND (NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(AH_CTA_VISTAS.SAL_TOTAL,0) - NVL(AH_CTA_VISTAS.SAL_RETENIDO,0) OR
                              NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(AH_CTA_VISTAS.SAL_TOT_BATCH,0) - NVL(AH_CTA_VISTAS.SAL_RET_BATCH,0))
                         AND EXISTS (SELECT 1
                                       FROM GE_EXT_ASCII_TMP X
                                      WHERE X.COD_PERSONA = GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA
                                        AND X.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA))
       UNION ALL
       SELECT GE_EXT_CLIENTES_TMP.COD_PERSONA, GE_EXT_CLIENTES_TMP.COD_EXTRACTO, GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
         FROM GE_EXT_CLIENTES_TMP
        WHERE GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual
          AND EXISTS (SELECT 0
                        FROM CC_CTA_CORRIENTES, GE_EXT_CLI_CUENTAS_TMP
                       WHERE CC_CTA_CORRIENTES.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA
                         AND CC_CTA_CORRIENTES.COD_MODALIDAD = GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD
                         AND CC_CTA_CORRIENTES.COD_OFICINA = GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA = GE_EXT_CLIENTES_TMP.COD_PERSONA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO = GE_EXT_CLIENTES_TMP.COD_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO = GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO = GE_EXT_CLIENTES_TMP.FRE_EXTRACTO
                         AND CC_CTA_CORRIENTES.COD_MODULO = 4
                         AND (NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(CC_CTA_CORRIENTES.SAL_TOTAL,0) - NVL(CC_CTA_CORRIENTES.SAL_RETENIDO,0) OR
                              NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(CC_CTA_CORRIENTES.SAL_TOT_BATCH,0) - NVL(CC_CTA_CORRIENTES.SAL_RET_BATCH,0))
                         AND EXISTS (SELECT 1
                                       FROM GE_EXT_ASCII_TMP X
                                      WHERE X.COD_PERSONA = GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA
                                        AND X.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA));
    BEGIN
       --Actualiza con lower (minuscula las cuentas que tuvieron dif. ---
       --para que no imprima con los demas extractos --------------------
       FOR CA IN DIFEREN LOOP
         UPDATE GE_EXT_CLIENTES_TMP
            SET GE_EXT_CLIENTES_TMP.FRE_EXTRACTO = LOWER(GE_EXT_CLIENTES_TMP.FRE_EXTRACTO)
          WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = CA.COD_PERSONA
            AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = CA.COD_EXTRACTO
            AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = CA.FEC_EXTRACTO;
       END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'Error al marcar diferencias '||sqlerrm);
   end lp_mar_ext_con_diferencia;

   procedure lp_mar_ext_con_dif_detalle is
    --Si tiene parámetro por persona o cuenta trae solo esos movientos--
    CURSOR DIFEREN IS
        SELECT GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO
          FROM GE_TRANSACCIONES, GE_EXT_CLI_MOVIMIENTOS_TMP, GE_EXT_CLI_CUENTAS_TMP
         WHERE GE_TRANSACCIONES.COD_MODULO = GE_EXT_CLI_MOVIMIENTOS_TMP.COD_MODULO
           and GE_TRANSACCIONES.COD_MODALIDAD = GE_EXT_CLI_MOVIMIENTOS_TMP.COD_MODALIDAD
           and GE_TRANSACCIONES.COD_TRANSACCION = GE_EXT_CLI_MOVIMIENTOS_TMP.COD_TRA_PADRE
           and GE_EXT_CLI_MOVIMIENTOS_TMP.COD_PERSONA = GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.COD_EXTRACTO = GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.FEC_EXTRACTO = GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA
          AND GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO = v_fec_actual
           AND GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA = 'A'
           AND EXISTS (SELECT 1
                         FROM GE_EXT_ASCII_TMP X
                        WHERE X.COD_PERSONA = GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA
                          AND X.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA)
         GROUP BY GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                  GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL
       HAVING DECODE(GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD,42,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR*-1, 48,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR*-1, 49,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR*-1,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR) +
        (SUM(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO) - SUM(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO))
         != DECODE(GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD,42,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL*-1,48,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL*-1,49,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL*-1,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL);
    BEGIN
      FOR CA IN DIFEREN LOOP
        UPDATE GE_EXT_CLIENTES_TMP
           SET GE_EXT_CLIENTES_TMP.FRE_EXTRACTO = LOWER(GE_EXT_CLIENTES_TMP.FRE_EXTRACTO)
         WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = CA.COD_PERSONA
           AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = CA.COD_EXTRACTO
           AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004,'Error al marcar dif. detalle '||sqlerrm);
   end lp_mar_ext_con_dif_detalle;

   procedure lp_act_deb_cre_negativos is
    BEGIN
       --Actualiza Debitos Negativos a Creditos--
       UPDATE GE_EXT_CLI_MOVIMIENTOS_TMP
          SET GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO = ABS(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO),
              GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO = 0
        WHERE GE_EXT_CLI_MOVIMIENTOS_TMP.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.USU_INSERCION = USER -- para que actualice solo los generados por el usuario logueado
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO < 0;
       --Actualiza Creditos Negativos a Debitos--
       UPDATE GE_EXT_CLI_MOVIMIENTOS_TMP
          SET GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO = ABS(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO),
              GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO = 0
        WHERE GE_EXT_CLI_MOVIMIENTOS_TMP.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.USU_INSERCION = USER -- para que actualice solo los generados por el usuario logueado
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO < 0;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'Error al actualizar creditos negativos '||sqlerrm);
   end lp_act_deb_cre_negativos;
begin
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Truncado de Tablas Temporales--
  pr_tru_tab_temporales;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_tru_tab_temporales', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');  
  --Insertar Tabla temporal de clientes para ASCII--
  pr_ins_tab_tmp_ascii;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_tab_tmp_ascii', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Actualizar cod_extracto de Tabla temporal--
  pr_act_dat_cod_extracto;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_act_dat_cod_extracto', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Insercion de Movimientos de Ahorros--
  pr_ins_mov_ahorros;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_mov_ahorros', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Insercion de Movimientos de Cuentas Corrientes--
  pr_ins_mov_ctacte;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_mov_ctacte', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Eliminacion de Movimientos de Extractos Anteriores--
  pr_eli_ext_generado;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_eli_ext_generado', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Insercion de Movimientos de Extractos de Ctacte--
  pr_ins_mov_ext_det_ctacte;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_mov_ext_det_ctacte', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Insercion de Movimientos de Extractos de Ahorro Vista--
  pr_ins_mov_ext_det_ahovista;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_mov_ext_det_ahovista', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  
  --Insertar la cabecera del Cliente--
  pr_ins_cli_ext_temporal;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_cli_ext_temporal', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Insertar la cabecera del Cliente--
  pr_ins_cue_ext_temporal;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','pr_ins_cue_ext_temporal', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --actualizacion de montos negativos--
  lp_act_deb_cre_negativos;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','lp_act_deb_cre_negativos', v_fecha, v_hor_inicio, v_hor_fin);
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Marcar Extactos con diferencia--
  lp_mar_ext_con_diferencia;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','lp_mar_ext_con_diferencia', v_fecha, v_hor_inicio, v_hor_fin);     

  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');  
  lp_mar_ext_con_dif_detalle;
  commit;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prg_gen_mov_ext_tmp','lp_mar_ext_con_dif_detalle', v_fecha, v_hor_inicio, v_hor_fin);     

end;
/

