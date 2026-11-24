create or replace function it.FUG_OBT_DAT_TRA_ATM(P_COD_PERSONA       IN VARCHAR2, --Código de la persona
                                               P_DIA_O_SEMANA      IN VARCHAR2 DEFAULT 'D', -- D-dia o S-semana
                                               P_CAN_O_MONTO       IN VARCHAR2 DEFAULT 'C', --C-cantidad o M-monto
                                               P_TIPO              IN VARCHAR2 DEFAULT NULL, -- L-local o E-extranjera
                                               P_COD_MON_RESULTADO IN VARCHAR2 DEFAULT NULL) --moneda p/ totalizar
 return number is
  v_cantidad      number;
  v_monto         number(18, 2);
  v_fec_inicio    date := pag_cal.fu_obt_fec_anterior(1);
  v_mon_destino   ba_monedas.cod_moneda%type;
begin
  --Semana
  if nvl(p_dia_o_semana, 'D') != 'D' then
    v_fec_inicio := pag_cal.fu_obt_fec_actual(1) - 7;
  end if;

  --Moneda a utilizar para el Total (USD por default)
  v_mon_destino := nvl(P_COD_MON_RESULTADO,pag_gen.fu_obt_mon_fuerte);

  -- Obtener la cantidad y el total de transacciones
  select count(*),
         sum(pag_gen.fu_con_mon_a_moneda(a.cod_moneda,
                                         v_mon_destino,
                                         a.monto))
    into v_cantidad, v_monto
    from gv_mov_captaciones a
   where substr(cod_usuario,1,3) = 'ATM'
     and nvl(cod_tip_movimiento, 'x') <> 'C'
     and cod_persona = p_cod_persona
     and fecha >= v_fec_inicio
     and cod_tra_padre <> 309
     and ((cod_tra_padre IN (374, 375, 376, 377) and NVL(p_tipo, 'E') = 'E') or
         (cod_tra_padre NOT IN (374, 375, 376, 377) and NVL(p_tipo, 'L') = 'L'));

  --Retornar Monto o Cantidad
  if nvl(p_can_o_monto,'C') = 'C' then
    return v_cantidad;
  else
    return v_monto;
  end if;

exception
  when others then
    raise_application_error(-20000, 'FUG_OBT_DAT_TRA_ATM ' || sqlerrm);
end FUG_OBT_DAT_TRA_ATM;
/

