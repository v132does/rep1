create or replace function it.FUG_EXT_EMINCO
  (p_cod_persona in varchar2,
   p_nro_cuenta  in varchar2 default null,
   p_fec_extracto in date)
 return clob is
  --comprimido 40 de ancho
  v_ancho           number(3) := 110; -- ancho del reporte
  v_resultado      clob := null;
  v_linea          varchar2(200);
  v_nom_cliente       ge_ext_clientes.nom_cliente%type;
  v_sal_actual        number(18,2);
  v_cod_oficina       ge_cuentas.cod_oficina%type;
  vpad1 number default 0;
  vpad2 number default 0;
  vpad3 number default 0;
  vpad4 number default 0;

cursor cuentas is
   select a.nro_cuenta, b.denominacion,a.cod_modalidad, fug_obt_des_modal(b.cod_modulo, a.cod_modalidad) des_modalidad,
          a.cod_oficina, fue_obt_des_oficina(a.cod_oficina) des_oficina,
          a.cod_moneda,a.sal_anterior,a.fec_extracto,a.cod_persona,
          a.sal_actual, a.sal_a_confirmar, fue_obt_des_moneda(a.cod_moneda) des_moneda
     from ge_cuentas b, ge_ext_cli_cuentas a
    where a.cod_persona = p_cod_persona
      and a.fec_extracto = p_fec_extracto
      and a.nro_cuenta = nvl(p_nro_cuenta,a.nro_cuenta)
       and a.nro_cuenta = b.nro_cuenta;

cursor movimientos(p_nro_cuenta in varchar2) is
select e.cod_persona de_cdclien,
      e.cod_extracto de_cdextra,
      e.fec_extracto de_fcextra,
      e.nro_cuenta de_nrcuent,
      to_number(e.nro_cuenta) cta,
      to_char( nvl( e.fec_movimiento, sysdate ), 'dd' ) movim,
      to_char( nvl( e.fec_valor, sysdate ), 'DD/MM' ) VALOR,
      e.nro_documento docum,
      e.cod_tra_padre tranp,
      substr(fue_obt_titulo( t.descripcion ),1,33) nmtrans,
      e.mto_debito debito,
      e.mto_credito credito,
      lower( substr( rutina1, 1, 7 ) ) ruti1,
      greatest( e.fec_movimiento, e.fec_valor ) fecha,
      e.nro_secuencia secuen,
      e.cod_ofi_origen,
      e.cod_modulo,
      e.fec_extracto,
      rownum registro,
e.fec_insercion
 , TO_DATE(E.HOR_MOVIMIENTO,'HH24:MI:SS') HOR_ORDEN
 from ge_transacciones t, ge_ext_cli_movimientos e
where t.cod_modulo = e.cod_modulo
  and t.cod_modalidad = e.cod_modalidad
  and t.cod_transaccion = e.cod_tra_padre
  and e.cod_persona = p_cod_persona
  and e.nro_cuenta = p_nro_cuenta
  and e.fec_extracto between 
      (select pri_dia_mes from ge_calendarios where cod_modulo = t.cod_modulo) 
        and p_fec_extracto
order by e.fec_insercion;

function lf_for_monto(p_monto in number)
  return varchar2 is
v_retorno varchar2(30);
begin
    v_retorno := lpad(to_char(nvl(p_monto,0),'999G999G999G999G990D00'),23,' ');
    return v_retorno;
end;

function lf_obt_movimiento(p_cta in varchar2,
                           p_fec in date)
  return boolean is
    v_existe varchar2(1) default 'N';
  begin
    begin
      select 'S' into v_existe
      from ge_ext_cli_movimientos 
      where nro_cuenta = p_cta
      and fec_extracto = p_fec
      and rownum = 1;
      if v_existe = 'S' then
        return true;
      else
        return false;
      end if;
    exception
      when no_data_found then
        return false;
      when others then
        return false;
    end;
  end;

begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(fug_obt_ofi_cliente(p_cod_persona));
  -- seteo el ancho del reporte
--  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  pag_imp.PR_IMP_CAB_AJUSTADA(v_resultado,'','',1);

  for ct in cuentas loop
    if lf_obt_movimiento(ct.nro_cuenta,ct.fec_extracto) then
      begin
        select a.cod_oficina
          into v_cod_oficina
          from ge_cuentas a
         where a.nro_cuenta = ct.nro_cuenta;
      exception
        when no_data_found then
        v_cod_oficina := null;
        when others then
        v_cod_oficina := null;
      end;
      v_nom_cliente := fue_obt_nom_persona(ct.cod_persona);
      
      
      v_linea := 'Sucursal ..: '||v_cod_oficina||' Cuenta: '||ct.nro_cuenta;
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
      
      
      v_linea := 'Titular(es): '||v_nom_cliente;
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
      
      
      v_linea := 'DIA             CONCEPTO                      NUMERO            DEBE             HABER               SALDO';
      pag_imp.pr_imp_linea(v_resultado, v_linea, 2);
      
      
      v_linea := lpad('=',v_ancho,'=');
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
      
      
      v_linea := 'SALDO ANTERIOR                                                                      '||lf_for_monto(ct.sal_anterior);
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
      
      
      v_sal_actual := nvl(ct.sal_anterior,0);
      -- movimientos
      
      
      for mv in movimientos(ct.nro_cuenta) loop


        if mv.debito <> 0 then
           v_sal_actual := v_sal_actual - mv.debito;
        elsif mv.credito <> 0 then
           v_sal_actual := v_sal_actual + mv.credito;
        end if;
        /*41''6''17''17 ''18 +*/
        
--        v_linea := mv.movim||' '||rpad(nvl(to_char(mv.docum),' '),10,' ')||rpad(nvl(mv.nmtrans,' '),33,' ')||lf_for_monto(mv.debito)||' '||lf_for_monto(mv.credito)||' '||lf_for_monto(v_sal_actual);
        vpad1 := 42;
        vpad2 := 6;
        vpad3 := 17;
        vpad4 := 18;
        v_linea := mv.movim||' '||rpad(nvl(mv.nmtrans,' '),vpad1,' ')||' '||lpad(nvl(to_char(mv.docum),' '),vpad2,' ')||lpad(lf_for_monto(mv.debito),vpad3,' ')||' '||lpad(lf_for_monto(mv.credito),vpad3,' ')||' '||lpad(lf_for_monto(v_sal_actual),vpad4,' ')||'+';
        pag_imp.pr_imp_linea(v_resultado, v_linea, 1);


      end loop;
      v_linea := lpad('=',v_ancho,'=');
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
      v_linea := 'SALDO ACTUAL                                                                        '||lf_for_monto(ct.sal_actual);
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
      v_linea := lpad('=',v_ancho,'=');
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
    end if;
  end loop;

  return(REPLACE(v_resultado,'~',''));

end FUG_EXT_EMINCO;
/

