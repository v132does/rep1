CREATE OR REPLACE PROCEDURE IT.PRC_CAN_LIN_SOB_SUELDOS(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null) is

  v_nro_cuenta     cc_lin_sobregiros.nro_cuenta%type;
  v_nro_secuencia  cc_lin_sobregiros.nro_secuencia%type;
  v_count          number;
  v_can_dias       number;
  v_observacion    cc_lin_sobregiros.observacion%type;
  v_tip_persona    ba_personas.tipo%type;
  rg_calend        ge_calendarios%rowtype;
  v_fec_actual     date;

  --Cursor p/ traer las lineas de sobregiro a cancelar
  -- Se cancelan las lineas de las Cuentas Pago de Salario
  -- que no tuvieron crédito de Sueldo en los ultimos X dias (45 dias por default)
  cursor cur_cte is
    select b.*
      from cc_cta_corrientes c, cc_lin_sobregiros b
     where c.nro_cuenta = b.nro_cuenta
       and c.cod_ente is not null
       and c.estado not in ('C', 'P', 'A', 'T', 'D', 'X')
       and c.acu_sobregiro = 'S'
       and b.estado in ('A', 'V')
       and not exists (Select 1 from ba_tab_dat_adicionales x
                       where x.tab_relacion = 'CC_LIN_SOBREGIROS'
                         and x.parametro = 'NRO_CTA_RELACIONADA'
                         and x.val_parametro = b.nro_cuenta
                         and x.referencia = b.nro_secuencia)  -- OMM 12/08/2015: Verifica si existe sobregiro aprobado por campaña
       and ((p_nro_cuenta is null and not exists
            (select 1
                from ge_pag_sueldos s
               where s.nro_cuenta = c.nro_cuenta
                 and s.procesado = 'S'
                 and s.tipo = 'C'
                    -- FB: 21.06.2010 Validación para no considerar los registros con monto cero
                 and nvl(s.monto, 0) > 0
                 and s.fec_proceso >= (v_fec_actual - v_can_dias))) or
           (p_nro_cuenta is not null and p_nro_cuenta = c.nro_cuenta));

begin
  v_can_dias    := nvl(fug_obt_pardinamico('DIA_CAN_LIN_SOB_SUELDO',null,null,null,null,null),45);
  v_observacion := ' * '||to_char(pag_cal.fu_obt_fec_actual(4),'dd/mm/yyyy')||' - Cancelado por falta de Crédito de Sueldo.';
  v_fec_actual  := pag_cal.fu_obt_fec_actual(4);
  rg_calend     := pag_cal.fu_obt_reg_cal(4);

  --Se debe procesar el primer dia habil de cada mes
  if v_fec_actual = rg_calend.pri_dia_mes_habil or p_nro_cuenta is not null then
    for k in cur_cte loop
      v_nro_cuenta    := k.nro_cuenta;
      v_nro_secuencia := k.nro_sec_padre;

      select count(1)
        into v_count
        from cc_lin_sobregiros a
       where a.nro_sec_padre = v_nro_secuencia;

      --Traer tipo de Persona del Firmante Principal
      begin
        select b.tipo
          into v_tip_persona
          from ge_cta_clientes c, ba_personas b
         where c.cod_persona = b.cod_persona
           and c.nro_cuenta = k.nro_cuenta
           and c.relacion = 'P';
      exception
        when others then
          v_tip_persona := null;
      end;

      --Verifico que este aplicado a una sola cuenta y que el firmante principal sea una persona Fisica
      if nvl(v_count,0) = 1 and nvl(v_tip_persona,'X') = 'F' then
        --Cancelar la Línea
        update cc_lin_sobregiros a
           set a.estado = 'C',
               a.observacion = nvl(a.observacion,' ')||v_observacion
         where a.nro_secuencia = k.nro_sec_padre;
        prc_eli_lin_sobregiro(k.nro_sec_padre,k.nro_linea,'S');
      end if;
    end loop;
  end if;
exception
  when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,'PRC_ELI_LIN_SOB_SUELDOS: Cta.: '||v_nro_cuenta||'; Sec.: '||v_nro_secuencia||'.'||SQLERRM);
     end if;
end PRC_CAN_LIN_SOB_SUELDOS;
/

