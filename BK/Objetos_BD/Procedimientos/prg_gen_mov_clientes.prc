CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_CLIENTES IS
  v_cod_mon_fuerte ba_monedas.cod_moneda%type;
  v_monto          ge_movimientos.MONTO%type;
  v_fec_desde      date;
  v_fec_hasta      date;
  v_cod_gru_tra    ge_gru_transacciones.cod_gru_transaccion%type;
  v_monto2         number;

  rg_gmrcl ge_mov_res_clientes%rowtype;
  --- Este proceso agrupa los movimientos de clientes en base a las transacciones que se requieran
  --- Cursor de ge_movimientos y solo tomar las transacciones que correspondan a ge_gru_transacciones_det del
  --- parametro dinamico que creamos
  cursor movimientos is
    select m.fecha,
           m.hora,
           m.cod_usuario,
           m.fec_valor,
           m.nro_cuenta,
           m.cod_moneda,
           m.cod_ofi_origen,
           m.cod_tra_padre,
           m.cod_mod_padre,
           m.cod_mad_padre,
           m.cotizacion,
           m.nro_documento,
           t.tipo tip_movimiento,
           protegido,
           m.cod_modulo,
           m.cod_modalidad,
           sum(m.monto) monto,
           sum(m.mto_equ_local) mto_equ_local
      from ge_movimientos m, ge_transacciones t
     where m.cod_mod_padre in (7, 9)
       and m.nro_caja is not null
       and t.cod_modulo = m.cod_modulo
       and t.cod_modalidad = m.cod_modalidad
       and t.cod_transaccion = m.cod_transaccion
       and m.reversado = 'N'
       and ((m.cod_mod_padre = 7 and m.nro_secuencia = 1) or
           (m.cod_mod_padre <> 7 and t.tipo = 'C'))
       and not exists (select 1
              from ah_cta_certificados
             where nro_cuenta = m.nro_cuenta
               and nro_cta_renovada is not null)
          -- No incluir CDA renovados
       and m.monto > 0
       and m.cod_modulo in (3, 4, 7)
     group by m.fecha,
              m.hora,
              m.cod_usuario,
              m.fec_valor,
              m.nro_cuenta,
              m.cod_moneda,
              m.cod_ofi_origen,
              m.cod_tra_padre,
              m.cod_mod_padre,
              m.cod_mad_padre,
              m.cotizacion,
              m.nro_documento,
              t.tipo,
              protegido,
              m.cod_modulo,
              m.cod_modalidad;

  
  FUNCTION LF_OBT_MTO_EQU_FIT (p_fecha          IN ge_mov_res_clientes.fecha%TYPE,
                               p_hora           IN ge_mov_res_clientes.hora%TYPE,
                               p_nro_cuenta     IN ge_mov_res_clientes.nro_cuenta%TYPE,

                               p_cod_moneda     IN ge_movimientos.cod_moneda%TYPE,                                      
                               p_cod_mon_fuerte IN ge_movimientos.cod_moneda%TYPE,
                               p_monto          IN ge_movimientos.monto%TYPE,
                               p_cotizacion     IN ge_movimientos.cotizacion%TYPE)
  return number is
  v_monto cj_acu_imp_transacciones.monto%type := null;
  begin

  begin
    select t.monto
        into v_monto
        from cj_acu_imp_transacciones t
       where t.fecha = p_fecha
         and t.hora = p_hora
         and t.nro_cuenta = p_nro_cuenta;
   exception
      when no_data_found then
         v_monto:= pag_gen.FU_CON_MON_A_MONEDA(p_cod_moneda,
                                               p_cod_mon_fuerte,
                                               p_monto,
                                               p_cotizacion);                                  
   end;
                                                             
  return v_monto;
  end;
  

  PROCEDURE PL_INS_GE_MOV_RES_CLIENTES IS
  BEGIN
    insert into ge_mov_res_clientes
      (fecha,
       hora,
       cod_usuario,
       cod_persona,
       fec_valor,
       monto,
       nro_cuenta,
       cod_moneda,
       cod_ofi_origen,
       cod_tra_padre,
       cod_mod_padre,
       cod_mad_padre,
       mto_equ_local,
       mto_equ_mon_fuerte,
       cotizacion,
       nro_documento,
       informado,
       cod_modulo,
       cod_modalidad,
       tip_mov_rubro,
       ano,
       mes)
    values
      (rg_gmrcl.fecha,
       rg_gmrcl.hora,
       rg_gmrcl.cod_usuario,
       rg_gmrcl.cod_persona,
       rg_gmrcl.fec_valor,
       rg_gmrcl.monto,
       rg_gmrcl.nro_cuenta,
       rg_gmrcl.cod_moneda,
       rg_gmrcl.cod_ofi_origen,
       rg_gmrcl.cod_tra_padre,
       rg_gmrcl.cod_mod_padre,
       rg_gmrcl.cod_mad_padre,
       rg_gmrcl.mto_equ_local,
       rg_gmrcl.mto_equ_mon_fuerte,
       rg_gmrcl.cotizacion,
       rg_gmrcl.nro_documento,
       rg_gmrcl.informado,
       rg_gmrcl.cod_modulo,
       rg_gmrcl.cod_modalidad,
       rg_gmrcl.tip_mov_rubro,
       rg_gmrcl.ano,
       rg_gmrcl.mes);
  END;
BEGIN
  v_cod_mon_fuerte := pag_gen.FU_OBT_MON_FUERTE;
  v_cod_gru_tra    := fug_obt_pardinamico('GRU_TRA_RES_MOV_CLIENTES');
  for reg in movimientos loop
    rg_gmrcl.fecha          := reg.fecha;
    rg_gmrcl.hora           := reg.hora;
    rg_gmrcl.cod_usuario    := reg.cod_usuario;
    rg_gmrcl.fec_valor      := reg.fec_valor;
    rg_gmrcl.monto          := reg.monto;
    rg_gmrcl.nro_cuenta     := reg.nro_cuenta;
    rg_gmrcl.cod_moneda     := reg.cod_moneda;
    rg_gmrcl.cod_ofi_origen := reg.cod_ofi_origen;
    rg_gmrcl.cod_tra_padre  := reg.cod_tra_padre;
    rg_gmrcl.cod_mod_padre  := reg.cod_mod_padre;
    rg_gmrcl.cod_mad_padre  := reg.cod_mad_padre;
    rg_gmrcl.cod_modulo     := reg.cod_modulo;
    rg_gmrcl.cod_modalidad  := reg.cod_modalidad;
    rg_gmrcl.mto_equ_local  := reg.mto_equ_local;
    rg_gmrcl.cotizacion     := reg.cotizacion;
    rg_gmrcl.nro_documento  := reg.nro_documento;
    rg_gmrcl.informado      := reg.protegido;
    rg_gmrcl.tip_mov_rubro  := reg.tip_movimiento;
    rg_gmrcl.ano            := to_number(to_char(reg.fecha, 'yyyy'));
    rg_gmrcl.mes            := to_number(to_char(reg.fecha, 'mm'));
    --- Recuperar datos de la persona
    if reg.cod_mod_padre = 7 then
      begin
        select to_char(a.nro_documento2) cod_persona
          into rg_gmrcl.cod_persona
          from lc_tip_operaciones c, ge_movimientos b, ge_movimientos a
         where a.cod_transaccion = 760
           and a.estado = 'N'
           and a.reversado = 'N'
           and a.fecha = b.fecha
           and a.cod_usuario = b.cod_usuario
           and a.hora = b.hora
           and b.cod_moneda <> pag_gen.fu_obt_mon_local
           and a.cod_mod_padre = 7
           and b.nro_secuencia = 1
           and c.cod_tip_operacion = b.cod_tip_ope_cambio
           and a.fecha = reg.fecha
           and a.hora = reg.hora
           and a.cod_usuario = reg.cod_usuario;
      exception
        when no_data_found then
          rg_gmrcl.cod_persona := null;
      end;
    elsif reg.nro_cuenta is not null then
      rg_gmrcl.cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
    else
      rg_gmrcl.cod_persona := null;
    end if;

    rg_gmrcl.mto_equ_mon_fuerte := LF_OBT_MTO_EQU_FIT(reg.fecha,
                                                      reg.hora,
                                                      reg.nro_cuenta,
                                                      
                                                      reg.cod_moneda,
                                                      v_cod_mon_fuerte,
                                                      reg.monto,
                                                      reg.cotizacion);    

                                                                                                         
                                                  
    PL_INS_GE_MOV_RES_CLIENTES;
  end loop;
END;
/

