create or replace function it.fug_gen_arc_txt_mes ( p_cod_persona  in varchar2,
                                                p_nro_cuenta   in varchar2,
                                                p_formato_gral in varchar2,
                                                p_fec_extracto in date)
return clob is

  v_file UTL_FILE.FILE_TYPE;
  v_path varchar2(100) := '/oradata/utl'; --'/tmp/archivos'
  v_tipo varchar2(01) := 'w'; -- reemplazar / a-agregar
------------------------
  --v_archivo clob;
------------------------
  v_s varchar2(1) default 'x';
  v_q varchar2(1) default 'x';
  v_m varchar2(1) default 'x';
  v_separador varchar2(10) := chr(9);
  v_fec_actual        ge_calendarios.fec_actual%type;
  v_fec_proxima       ge_calendarios.fec_proxima%type;
  v_pri_dia_mes       ge_calendarios.pri_dia_mes%type;
  v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%type;
  v_ult_dia_mes       ge_calendarios.ult_dia_mes%type;
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
  v_fec_extracto      ge_ext_clientes.fec_extracto%type := p_fec_extracto;
  v_nom_largo         varchar2(100):= fug_obt_nom('L');
  cursor c_gen_ext is
  select a.cod_persona, a.nro_cuenta, fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') frecuencia
    from ge_cta_clientes a
   where a.cod_persona = nvl(p_cod_persona,a.cod_persona)
     and a.nro_cuenta = nvl(p_nro_cuenta,a.nro_cuenta)
     and a.cod_modulo in (3,4)
     and a.cod_modalidad in (31,41)
     and fug_obt_paradicional(a.nro_cuenta,'EMAIL_ENVIO_EXT_ASCII') is not null
     and (fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') = v_s or
          fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') = v_q or
          fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') = v_m or
          fug_obt_paradicional(a.nro_cuenta,'EXT_ASCII') = 'D' );
  function lf_obt_fec_hab_quincena
   return date
   is
     v_fec_actual date := PAG_CAL.FU_OBT_FEC_ACTUAL(3);
     v_result date;
   begin
     if (to_char(to_date(15||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy'),'D') = 1)
       then
       v_result := to_date(16||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy');
     elsif (to_char(to_date(15||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy'),'D') = 7)
       then
       v_result := to_date(17||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy');
     else
       v_result := to_date(15||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy');
     end if;
     return pag_cal.FU_OBT_FEC_SIG_HAB(v_result-1, null); -- null para p_cod_oficina.
   end lf_obt_fec_hab_quincena;
   ---
procedure pp_gen_mov_ascii(p_cod_persona varchar2,p_nro_cta varchar2) is -- solo para eminco
  cursor cab_clie is
     select cod_oficina,nro_cuenta, cod_persona, fec_extracto, cod_moneda, fre_extracto, cod_extracto,
            nvl(a.sal_anterior,0) sal_anterior,
            nvl(a.sal_actual,0) sal_actual,
            sal_a_confirmar,
            sigla,  b.cod_modalidad
       from ge_ext_cli_cuentas a, ge_modalidades b
      where a.cod_modalidad = b.cod_modalidad
       and cod_persona = p_cod_persona
       and nro_cuenta = p_nro_cta
       and a.fec_extracto = v_fec_extracto
       and a.fre_extracto = 'M'
       and exists (select 1 from ge_ext_clientes c
                    where c.cod_persona  = a.cod_persona
                      and c.fec_extracto = a.fec_extracto
                      and c.fre_extracto = a.fre_extracto
                      and c.cod_extracto = a.cod_extracto)
      order by cod_persona,nro_cuenta,fec_extracto;
  --
  cursor det_clie(p_cta varchar2, p_fec_extracto date, p_cod_extracto number) is
     select fec_movimiento, fec_valor, hor_movimiento,
            lpad(substr(nvl(nro_documento,0),1,7),7,0) nro_documento,
             a.mto_credito, a.mto_debito,
            decode(a.mto_debito,0,
            trim(replace(to_char(nvl(a.mto_credito,0),'S000000000000D00'),'.',',')),
            trim(replace(to_char(nvl(a.mto_debito,0),'S000000000000D00'),'.',',') )) valor,
            descripcion, decode(a.mto_debito,0,'C','D') tipo, lpad(to_char(cod_tra_padre),3,0) cod_tra_padre
       from ge_ext_cli_movimientos a, ge_transacciones b
      where a.cod_tra_padre = b.cod_transaccion
      and a.cod_modulo = b.cod_modulo
      and a.cod_modalidad = b.cod_modalidad
      and cod_persona = p_cod_persona
      and fec_extracto = p_fec_extracto
      and cod_extracto = p_cod_extracto
      and nro_cuenta = p_cta
      and a.fec_extracto = v_fec_extracto
      and a.fre_extracto = 'M'
      order by a.fec_movimiento, a.fec_valor, a.hor_movimiento;
  --
  v_cabecera varchar2(1000);
  v_detalle varchar2(1000);
  v_nombre varchar2(356);
  v_sucursal varchar2(3);
  v_cont   number:=0;
  v_existe varchar2(1):=NULL;
  v_sum_mto_debito  number;
  v_sum_mto_credito number;
  v_count       number;
  v_tipo_cuenta  varchar2(1);
  v_sub_cuenta  varchar2(6);
  v_dia_habil   varchar2(12);
begin
  --determinar el tipo
  for reg in cab_clie loop
    select to_char(lpad(nvl(a.cod_oficina,0),2,0))into v_sucursal
      from ge_ext_clientes a
     where a.cod_persona= reg.cod_persona
       and a.cod_extracto= reg.cod_extracto
       and a.fec_extracto = reg.fec_extracto
       and a.fre_extracto = reg.fre_extracto;

    select to_char(a.pri_dia_mes_habil,'dd/mm/yyyy')  into v_dia_habil
      from ge_calendarios  a
     where a.cod_modulo= 1;

    select nvl(sum(a.mto_debito),0) v_sum_mto_debito,
           nvl(sum(a.mto_credito),0) v_sum_mto_credito,
           count(*)
      into v_sum_mto_debito, v_sum_mto_credito, v_count
      from ge_ext_cli_movimientos a, ge_transacciones b
     where a.cod_tra_padre = b.cod_transaccion
       and a.cod_modulo = b.cod_modulo
       and a.cod_modalidad = b.cod_modalidad
       and cod_persona = reg.cod_persona
       and nro_cuenta = reg.nro_cuenta
       and fec_extracto = reg.fec_extracto
       and fre_extracto = reg.fre_extracto
       and cod_extracto = reg.cod_extracto
     group by a.cod_persona, a.nro_cuenta;

    IF reg.cod_modalidad= 41 and reg.cod_moneda = 'GS' THEN
       v_tipo_cuenta:= '1';
       v_sub_cuenta:= '210100';
    elsif reg.cod_modalidad= 31  and reg.cod_moneda = 'GS' THEN
       v_tipo_cuenta:= '2';
       v_sub_cuenta:= '210500';
    elsif reg.cod_modalidad= 41  and reg.cod_moneda <> 'GS' THEN
       v_tipo_cuenta:= '3';
       v_sub_cuenta:= '215000';
    elsif reg.cod_modalidad= 31  and reg.cod_moneda <> 'GS' THEN
       v_tipo_cuenta:= '4';
       v_sub_cuenta:= '215500';
    end if;

    v_nombre := 'ex_'||lpad( p_cod_persona, 7, '0' )||'_'||reg.nro_cuenta||'_'||reg.fre_extracto||'_'||reg.cod_extracto||'.txt';

    -- abre el archivo
    IF UTL_FILE.IS_OPEN(v_file) = FALSE THEN
     	v_file := UTL_FILE.FOPEN(v_Path,v_nombre, v_tipo);
    END IF;

    --
    v_cabecera :=  v_sucursal||v_sub_cuenta||substr(reg.nro_cuenta,-6)||' '||rpad(reg.cod_moneda,3,' ')||
           v_dia_habil||to_char(reg.fec_extracto,'dd/mm/yyyy')||
           replace(to_char(reg.sal_anterior,'S00000000000000D00'),'.',',')||
           replace(to_char(v_sum_mto_credito,'S00000000000000D00'),'.',',')||
           replace(to_char(v_sum_mto_debito,'S00000000000000D00'),'.',',')||
           replace(to_char(reg.sal_actual,'S00000000000000D00'),'.',',')||
           lpad(v_count,5,'0');

    UTL_FILE.PUT_LINE(v_file, v_cabecera);

    v_existe := 'S';
    v_detalle := '';
    v_cont := 0;
    for reg1 in det_clie(reg.nro_cuenta,reg.fec_extracto,reg.cod_extracto) loop
      v_cont:= v_cont+1;
      v_detalle := to_char(reg1.fec_movimiento,'dd/mm/yyyy')||reg1.nro_documento||to_char(reg1.cod_tra_padre)
      ||reg1.tipo||reg1.valor||'0000000000';
      UTL_FILE.PUT_LINE(v_file, v_detalle);
    end loop;

    -- cierra el archivo
    UTL_FILE.FCLOSE(v_file); 

    ---
  end loop;

exception
  when others then
   if abs(sqlcode) =302000 then
      raise_application_error(-20000,'Directorio Inválido.');
    else
      raise_application_error(-20000,'Error '||sqlerrm);
    end if;
end;
---------------------------------
procedure pp_gen_mov_ascii_gral(p_cod_persona varchar2, p_nro_cta varchar2) is
--v_fec_extracto ge_ext_cli_cuentas.fec_extracto%type;
v_sal_anterior number;
v_saldo        number;
cursor cab_clie is
   select cod_oficina,nro_cuenta, cod_persona, fec_extracto, cod_moneda, fre_extracto, cod_extracto,
          (decode(sign(a.sal_anterior),-1,'-','')||nvl(abs(a.sal_anterior),0)) sal_anterior,
          (decode(sign(a.sal_actual),-1,'-','')||nvl(abs(a.sal_actual),0)) sal_actual, sal_a_confirmar, sigla
     from ge_ext_cli_cuentas a, ge_modalidades b
    where a.cod_modalidad = b.cod_modalidad
      and cod_persona = p_cod_persona
      and nro_cuenta = p_nro_cta
      and a.fec_extracto = v_fec_extracto
      and a.fre_extracto = 'M'
      and exists (select 1 from ge_ext_clientes c
                   where c.cod_persona  = a.cod_persona
                     and c.fec_extracto = a.fec_extracto
                     and c.fre_extracto = a.fre_extracto
                     and c.cod_extracto = a.cod_extracto)
    order by cod_persona,nro_cuenta,fec_extracto;

cursor det_clie(p_cta varchar2, p_fec_extracto date, p_cod_extracto number) is
   select fec_movimiento, fec_valor, hor_movimiento,
          nvl(nro_documento,0)nro_documento,
          nvl(a.mto_debito,0) mto_debito,
          nvl(a.mto_credito,0) mto_credito,
          substr(descripcion,1,41) descripcion
     from ge_ext_cli_movimientos a, ge_transacciones b
    where a.cod_tra_padre = b.cod_transaccion
    and a.cod_modulo = b.cod_modulo
    and a.cod_modalidad = b.cod_modalidad
    and cod_persona = p_cod_persona
    and fec_extracto = p_fec_extracto
    and cod_extracto = p_cod_extracto
    and nro_cuenta = p_cta
    and a.fec_extracto = v_fec_extracto
    and a.fre_extracto = 'M'
    order by fec_movimiento, fec_valor, hor_movimiento;

v_nombre_pers varchar2(220);
v_nombre varchar2(356);
v_linea  varchar2(1000);
v_oficina varchar2(100);
v_cont   number:=0;
v_existe varchar2(1):=NULL;
v_seq number default 0;
v_lugar varchar2(100);
v_archivo varchar2(4000);
begin
  for reg in cab_clie loop
    v_lugar := 'Inicio';
--    v_fec_extracto := reg.fec_extracto;

    v_nombre := 'ex_'||lpad( p_cod_persona, 7, '0' )||'_'||reg.nro_cuenta||'_'||reg.fre_extracto||'_'||reg.cod_extracto||'.xls';

    -- abre el archivo
    IF UTL_FILE.IS_OPEN(v_file) = FALSE THEN
     	v_file := UTL_FILE.FOPEN(v_Path,v_nombre, v_tipo);
    END IF;

    v_sal_anterior:= reg.sal_anterior;
    v_lugar := 'Nombre';
    select a.nom_completo into v_nombre_pers
    from ba_personas a
    where a.cod_persona=reg.cod_persona;
    v_lugar := 'oficina';
    select b.cod_oficina||' '||b.descripcion into v_oficina
    from ba_oficinas b
    where b.cod_oficina= reg.cod_oficina;
    v_lugar := 'nombre extracto';
    v_seq := v_seq + 1;
    v_nombre:='ex_'||lpad( p_cod_persona, 7, '0' )||'_'||reg.nro_cuenta||'_'||reg.fre_extracto||'_'||'_'||v_seq||'.txt';
    v_lugar := 'cabecera';

    --v_linea:= 'Banco Bilbao Vizcaya Argentaria Paraguay S.A.'||v_separador||v_separador||v_separador||v_separador||v_separador||to_char(reg.fec_extracto,'dd/mm/yyyy')||chr(13);
    v_linea:= v_nom_largo||v_separador||v_separador||v_separador||v_separador||v_separador||to_char(reg.fec_extracto,'dd/mm/yyyy')||chr(13);
    
    v_archivo := v_linea;
    v_linea:= 'Extracto Mensual'||chr(13);
    v_archivo := v_archivo||v_linea;

    v_linea :='Sucursal: '||v_oficina||'    Cuenta: '||rpad(reg.nro_cuenta,20,' ')||chr(13);
    v_archivo := v_archivo||v_linea;
    v_linea :='Titular(es): '||v_nombre_pers||chr(13);
    v_archivo := v_archivo||v_linea;

    v_existe := 'S';

    v_linea :='Dia'||v_separador||'Concepto'||v_separador||'Num.Doc.'||v_separador||'Debe'||v_separador||'Haber'||v_separador||'Saldo'||chr(13);
    v_archivo := v_archivo||v_linea;
    --
    UTL_FILE.PUT_LINE(v_file, v_archivo);
    
    v_lugar := 'detalle';
    v_linea := '';
    for reg1 in det_clie(reg.nro_cuenta,reg.fec_extracto,reg.cod_extracto) loop
      if v_cont = 571 then
        v_cont:= v_cont;
      end if;
      v_cont:= v_cont + 1;

      if v_cont = 1 then        --calcula el saldo
        v_saldo:= nvl(v_sal_anterior,0) - nvl(reg1.mto_debito,0) + nvl(reg1.mto_credito,0) ;
        --
        v_linea :=v_separador||'Saldo Anterior'||v_separador||v_separador||v_separador||v_separador||replace(trim(to_char(nvl(reg.sal_anterior,0),'9999999999999999D99')),',','.')||chr(13);
      else
        v_saldo:= v_saldo - nvl(reg1.mto_debito,0) + nvl(reg1.mto_credito,0) ;
      end if;

      v_lugar := 'detalle '||v_cont;
      v_linea := v_linea||to_char(reg1.fec_movimiento,'dd')
              ||v_separador||replace(reg1.descripcion,',','.')
              ||v_separador||to_char(reg1.nro_documento)
              ||v_separador||replace(trim(to_char(reg1.mto_debito, '9999999999999D99')),',','.')
              ||v_separador||replace(trim(to_char(reg1.mto_credito,'9999999999999D99')),',','.')
              ||v_separador||replace(trim(to_char(nvl(v_saldo,0),'9999999999999D99')),',','.');
      UTL_FILE.PUT_LINE(v_file, v_linea);
      v_linea := '';        

    end loop;
    --v_archivo := v_archivo||v_linea;
    v_lugar := 'Pie de pagina';

    v_linea:=v_separador||'Saldo Actual'||v_separador||v_separador||v_separador||v_separador||replace(trim(to_char(reg.sal_actual,'9999999999999999D99')),',','.')||chr(13);
    UTL_FILE.PUT_LINE(v_file, v_linea);

    -- cierra el archivo
    UTL_FILE.FCLOSE(v_file);    
    
    --v_archivo := v_archivo||v_linea;
  end loop;
exception
  when others then
    if abs(sqlcode) =302000 then
      raise_application_error(-20000,'Directorio Inválido.');
    else
      raise_application_error(-20000,'Error  en '||v_lugar||' - '||sqlerrm);
    end if;
end;
--
begin
  begin
    select fec_actual, fec_proxima,
           pri_dia_mes, pri_dia_mes_habil, ult_dia_mes, ult_dia_mes_habil
      into v_fec_actual, v_fec_proxima,
           v_pri_dia_mes, v_pri_dia_mes_habil, v_ult_dia_mes, v_ult_dia_mes_habil
      from ge_calendarios
     where cod_modulo = 1;
  exception
    when no_data_found then
      raise_application_error(-20000,'Error al Buscar datos de Calendarios');
    when others then
      raise_application_error(-20000,'Error Calendarios '||sqlerrm);
  end;

  if to_number(to_char(v_fec_actual, 'D')) > to_number(to_char(v_fec_proxima,'D')) or
     v_fec_actual = v_ult_dia_mes_habil Then
    v_s := 'S'; -- Frecuencia Semanal.
  end if;

  if v_fec_actual = lf_obt_fec_hab_quincena then
    v_q := 'Q';
  end if;

  If v_fec_actual = v_ult_dia_mes_habil Then
    v_m := 'M';
  end if;

  if ((p_cod_persona is null and p_nro_cuenta is null) or
      (p_cod_persona is null and p_nro_cuenta is not null) or
      (p_cod_persona is not null and p_nro_cuenta is null)) then
    for k in c_gen_ext loop
      if nvl(p_formato_gral,'N') = 'S' then
        pp_gen_mov_ascii_gral(k.cod_persona,k.nro_cuenta);
      else
        pp_gen_mov_ascii(k.cod_persona,k.nro_cuenta); -- formato eminco
      end if;
    end loop;
  else
    --
    if nvl(p_formato_gral,'N') = 'S' then
      pp_gen_mov_ascii_gral(p_cod_persona,p_nro_cuenta);
    else
      pp_gen_mov_ascii(p_cod_persona,p_nro_cuenta);
    end if;
  end if;
  return '';
exception
  when others then
    raise_application_error(-20000,'Error al generar archivo '||sqlerrm);
end;
/

