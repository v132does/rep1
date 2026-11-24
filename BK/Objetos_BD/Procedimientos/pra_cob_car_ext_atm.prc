create or replace procedure it.pra_cob_car_ext_atm
 (p_nro_cuenta in varchar2 default null) is

  V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_car_mas_iva       number(18,2);

  v_hor_actual        varchar2(08) ;
  v_fec_actual        date;
  v_nro_secuencia     number(3) := 0;
   v_nvo_estado        varchar2(1);
  v_sal_disponible    number;
  v_procesa           varchar2(1);
  --
  v_cod_mod_cargo     number(3) := 3;   -- modulo de ahorros
  v_cod_mad_cargo     number(3) := 31;  -- modalidad de ahorros vista
  v_cod_tra_cargo     number(6) := 145; -- codigo de transaccion por uso de otro atm
  
  v_cod_gru_transaccion number(5) := 52; -- grupo que contiene las transacciones que deben ser contadas
  
   V_VAL_TAS_IMPUESTO2     GE_MOVIMIENTOS.VAL_TASA%TYPE;
   V_VAL_IMPUESTO2         GE_MOVIMIENTOS.VAL_TASA%TYPE;
   V_ind_tra_atm          varchar2(1) := 'N';
  
cursor ctas is
  select nro_cuenta,cod_moneda,cod_oficina
    from ah_cta_vistas
    where nro_cuenta = nvl(p_nro_cuenta,nro_cuenta)
      and cod_modulo    = v_cod_mod_cargo
      and cod_modalidad = v_cod_mad_cargo
     -- and cod_ente is null  -- no toma en cuenta las cuentas plan sueldo
      and estado not in ('T','C','A','X');
begin
  v_fec_actual := pag_cal.fu_obt_fec_actual('4');
  v_hor_actual := fug_ini_hora(sysdate,'HH24:MI:SS');

  for reg in ctas loop
    if v_nro_secuencia > 990 then
       v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
       v_nro_secuencia := 0;
    end if;

    --Se cobra cargos por la operacion si corresponde
    prg_obt_car_uso_otr_atm  (reg.nro_cuenta,
                              v_cod_gru_transaccion,
                              V_COD_TAS_CARGO,
                              V_VAL_TAS_CARGO,
                              V_VAL_CARGO,
                              V_COD_TRA_IMPUESTO,
                              V_COD_TAS_IMPUESTO,
                              V_VAL_TAS_IMPUESTO,
                              V_VAL_IMPUESTO,
                              V_VAL_TAS_IMPUESTO2,
                              V_VAL_IMPUESTO2,
                              V_ind_tra_atm) ;

    v_car_mas_iva := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
    if v_car_mas_iva > 0 then
      pag_cta.G_COD_ERROR := 0;
      -- verifico si puedo o no cobrar el cargo + iva
      pag_cta.PR_VER_OPERACION(reg.nro_cuenta,
                               v_cod_tra_cargo, -- padre
                               v_cod_mod_cargo, 
                               v_cod_mad_cargo,
                               'D', -- TIPO DEBITO
                               reg.cod_moneda,
                               v_car_mas_iva,
                               reg.cod_oficina,
                               pag_cta.G_CTAS.COD_MODULO,
                               pag_cta.G_CTAS.COD_MODALIDAD,
                               v_nvo_estado,
                               v_sal_disponible,
                               v_procesa,
                               v_cod_tra_cargo);
      if v_procesa = 'N' then
         -- no se puede debitar
         insert into ge_mov_pendientes
                     (nro_cuenta,fecha, cod_modulo, cod_modalidad, cod_transaccion, 
                      cod_mod_padre, cod_mad_padre, cod_tra_padre, monto, 
                      hora, cod_usuario,  cod_moneda, 
                      cod_oficina, cod_error, estado, cod_ofi_origen, 
                      concepto, cod_tasa, val_tasa, nro_documento, saldo, motivo)
              values (reg.nro_cuenta, v_fec_actual, v_cod_mod_cargo, v_cod_mad_cargo, v_cod_tra_cargo,
                      v_cod_mod_cargo, v_cod_mad_cargo, v_cod_tra_cargo, v_car_mas_iva, 
                      v_hor_actual, user, reg.cod_moneda, 
                      reg.cod_oficina, pag_cta.g_cod_error, 'I', reg.cod_oficina,
                      'Cargo p/ Uso Atm Otro Bco.',V_COD_TAS_CARGO, V_VAL_TAS_CARGO, 
                      reg.nro_cuenta /* nro_documento=cuenta*/, v_car_mas_iva,
                      pag_cta.G_MSJ_ERROR);
      end if;                         
  
      if nvl(v_val_cargo,0) > 0 then
        pag_cta.G_COD_ERROR := 0;
        pag_cta.pr_act_operacion(reg.nro_cuenta,
                                 v_hor_actual,
                                 'D', -- debito a la cuenta del cliente
                                 reg.cod_moneda,
                                 v_val_cargo,
                                 v_cod_tra_cargo,
                                 v_cod_tra_cargo, -- trans. hijo
                                 reg.nro_cuenta,
                                 null, -- cotizacion
                                 reg.cod_oficina,
                                 v_cod_mod_cargo,
                                 v_cod_mad_cargo,
                                 V_COD_TAS_CARGO, -- tasa
                                 V_VAL_TAS_CARGO, -- valor de tasa
                                 'Cargo p/ Uso Atm Otro Bco.', --concepto
                                 'N', -- emitir aviso
                                 v_nro_secuencia, -- nro de secuencia
                                 v_fec_actual);
  
        if v_val_impuesto > 0 and  pag_cta.g_cod_error = 0 then
          pag_cta.pr_act_operacion(reg.nro_cuenta,
                                   v_hor_actual,
                                   'D', -- debito a la cuenta del cliente
                                   reg.cod_moneda,
                                   v_val_impuesto,
                                   V_COD_TRA_IMPUESTO,
                                   V_COD_TRA_IMPUESTO, -- trans. hijo
                                   reg.nro_cuenta,
                                   null, -- cotizacion
                                   reg.cod_oficina,
                                   v_cod_mod_cargo,
                                   v_cod_mad_cargo,
                                   V_COD_TAS_IMPUESTO, -- tasa
                                   V_VAL_TAS_IMPUESTO, -- valor de tasa
                                   'IVA s/Cargo por Uso.Otr.Atm', --concepto
                                   'N', -- emitir aviso
                                   v_nro_secuencia, -- nro de secuencia
                                   v_fec_actual);
  
        End if;
  
      End if;
    end if;
  end loop;
end pra_cob_car_ext_atm;
/

