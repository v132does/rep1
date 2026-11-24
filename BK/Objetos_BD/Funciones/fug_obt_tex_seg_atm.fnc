CREATE OR REPLACE FUNCTION IT."FUG_OBT_TEX_SEG_ATM" (p_cod_persona varchar2, p_indicador varchar2)
  return varchar2 is
  v_texto          varchar2(400);
  v_tex_ticket     varchar2(400);
  --v_resp           varchar2(320);
  v_des_seguro     ge_tip_seguros.descripcion%type;
  v_nro_cta        ge_cli_seguros.nro_cta_debito%type;
  v_char           varchar2(2) := 'N ';
  v_linea          varchar2(100);
  v_lin_ticket     varchar2(100);
  v_mto_cuota      ge_cuo_seguros.monto%type;
  v_fec_fus_legal  ge_calendarios.fec_actual%type := to_date(fug_obt_pardinamico('FEC_FUS_LEGAL'), 'ddmmyyyy');
  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(3);
begin
  begin
    select b.descripcion,a.nro_cta_debito,c.monto
      into v_des_seguro,v_nro_cta,v_mto_cuota
      from ge_cli_seguros a, ge_tip_seguros b, ge_cuo_seguros c
     where a.cod_tip_seguro = b.cod_tipo
       and a.cod_persona = p_cod_persona
       and a.estado = 'V'
       and a.nro_seguro = c.nro_seguro
       and b.cod_canal = 28 --ATM: DYDMR-12274
       and rownum = 1;
  exception
    when no_data_found then
      raise_application_error(-20000, 'No existe seguro para la persona ' || p_cod_persona);
    when others then
      raise_application_error(-20001, 'Error al buscar seguro para la persona ' || p_cod_persona||' '||sqlerrm);
  end;
  
  if v_fec_actual < v_fec_fus_legal then
    if p_indicador = 'P' then--pantalla
      v_linea := 'Gracias por contratar el servicio de  ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--1
      v_linea := v_des_seguro;
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--2
      v_linea := 'Permite recuperar el dinero en caso de';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--3
      v_linea := 'robo antes, durante y hasta 10 minutos';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--4
      v_linea := 'después de realizada la extracción.   ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--5
      v_linea := 'Las cuotas se le estaran debitando de ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--6
      v_linea := 'la cuenta: '||v_nro_cta||' Para más info   ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--7
      v_linea := 'de la póliza ingrese a www.bbva.com.py';
      v_texto := '08'||v_texto || rpad(v_char||v_linea,40,' ');--8
      return(v_texto);
    elsif p_indicador = 'T' then--ticket
      v_lin_ticket := 'Ud ha contratado el                    ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--1
      v_lin_ticket := v_des_seguro;
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--2
      v_lin_ticket := 'con un costo mensual de Gs. '||v_mto_cuota||'.';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--3
      v_lin_ticket := 'Para más info de la poliza ingrese a  ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--4
      v_lin_ticket := 'www.bbva.com.py o consulte a su Gestor';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--5
      v_lin_ticket := 'Comercial. Tendrá derecho a retractarse';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--6
      v_lin_ticket := 'dentro de 7 días en caso de desistir, ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--7
      v_lin_ticket := 'sin cargo si no utilizo el servicio.  ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--8
      return(v_tex_ticket); 
    end if;
  else
    if p_indicador = 'P' then--pantalla
      v_linea := 'Gracias por contratar el servicio de  ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--1
      v_linea := v_des_seguro;
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--2
      v_linea := 'Permite recuperar el dinero en caso de';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--3
      v_linea := 'robo antes, durante y hasta 10 minutos';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--4
      v_linea := 'después de realizada la extracción.   ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--5
      v_linea := 'Las cuotas se le estaran debitando de ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--6
      v_linea := 'la cuenta: '||v_nro_cta||' Para más info de ';
      v_texto := v_texto || rpad(v_char||v_linea,40,' ');--7
      v_linea := 'la póliza ingrese www.bancognb.com.py';
      v_texto := '08'||v_texto || rpad(v_char||v_linea,40,' ');--8
      return(v_texto);
    elsif p_indicador = 'T' then--ticket
      v_lin_ticket := 'Ud ha contratado el                    ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--1
      v_lin_ticket := v_des_seguro;
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--2
      v_lin_ticket := 'con un costo mensual de Gs. '||v_mto_cuota||'.';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--3
      v_lin_ticket := 'Para más info de la poliza ingrese a  ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--4
      v_lin_ticket := 'www.bancognb.com.py o consulte a su ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--5
      v_lin_ticket := 'Gestor. Tendrá derecho a retractarse ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--6
      v_lin_ticket := 'dentro de 7 días en caso de desistir, ';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--7
      v_lin_ticket := 'sin cargo si no utilizo el Servicio';
      v_tex_ticket := v_tex_ticket || rpad(v_lin_ticket,40,' ');--8
      return(v_tex_ticket);
    end if;
  end if;
    
end fug_obt_tex_seg_atm;
/

