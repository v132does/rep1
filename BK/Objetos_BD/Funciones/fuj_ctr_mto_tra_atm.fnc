create or replace function it.fuj_ctr_mto_tra_atm(p_nro_cuenta pr_cobros.nro_cuenta%type,
                                               p_importe    ge_movimientos.monto%type)
  return varchar2 is

  v_cod_persona ba_personas.cod_persona%type;
  v_monto       ge_movimientos.monto%type;
  v_mto_max_dia ge_movimientos.monto%type;
  v_retorno     varchar2(1) := 'N';
  v_mto_limite  ge_movimientos.monto%type := 10000000;

BEGIN
  v_mto_max_dia := fug_obt_pardinamico('LIM_GEN_TRANSFERENCIAS',
                                       null,
                                       null,
                                       pag_gen.FU_OBT_MON_LOCAL,
                                       null);

  select cta.cod_persona
    into v_cod_persona
    from ge_cta_clientes cta
   where cta.nro_cuenta = p_nro_cuenta
     and cta.relacion = 'P';

  select sum(v.monto)
    into v_monto
    from ge_cta_clientes c, ge_movimientos v
   where c.nro_cuenta = v.nro_cuenta
     and c.cod_persona = v_cod_persona
     and c.relacion = 'P'
     and v.COD_TRA_PADRE = 385
     and v.COD_TRANSACCION = 503
     and v.Fecha = pag_cal.fu_obt_fec_actual(1);

  if (nvl(v_monto, 0) + nvl(p_importe, 0)) <=
     nvl(v_mto_max_dia, v_mto_limite) then
    v_retorno := 'S';
  end if;

  return v_retorno;
EXCEPTION
  WHEN OTHERS THEN
    return v_retorno;
END;
/

