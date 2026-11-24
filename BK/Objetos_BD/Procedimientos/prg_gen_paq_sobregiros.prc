create or replace procedure it.prg_gen_paq_sobregiros(p_cod_paquete in ge_paq_cuentas.cod_paquete%type,
                                                   p_cod_persona in ba_personas.cod_persona%type,
                                                   p_nro_cuenta in ge_cuentas.nro_cuenta%type default null,
                                                   p_error in out varchar2) is

  v_nro_secuencia      cc_lin_sobregiros.nro_secuencia%type;
  v_nro_sec_padre      cc_lin_sobregiros.nro_secuencia%type;
  v_cod_moneda         cc_cta_corrientes.cod_moneda%type;
  v_observacion        cc_lin_sobregiros.observacion%type;
  v_lin_tarjeta        ta_cta_tarjetas.lin_credito%type;
  v_monto              cc_lin_sobregiros.monto%type;
  v_fecha              date;
  v_fec_vencimiento    date;
  v_porcentaje         number;
  v_cod_modulo         ge_modalidades.cod_modulo%type;
  v_cod_modalidad      ge_modalidades.cod_modalidad%type;
  v_cod_sub_modalidad  ge_sub_modalidades.cod_sub_modalidad%type;
  v_dias               number;
  v_des_paquete        ge_paquetes.descripcion%type;

--Buscar si el Cliente ya Tiene Línea de Sobregiro
function lf_obt_lin_sobregiro(p_nro_cuenta varchar2,
                              p_tipo       varchar2)
  return varchar2 is
  v_existe varchar2(1):= 'N';
begin
  begin
    select distinct 'S'
      into v_existe
      from cc_lin_sobregiros
     where nro_cuenta = p_nro_cuenta
       and tipo       = p_tipo;
  exception
    when no_data_found then
      begin
         select distinct 'S'
           into v_existe
           from cc_lin_sobregiros
          where cod_persona = p_cod_persona
            and tipo        = p_tipo;
      exception
        when no_data_found then
           v_existe := 'N';
      end;
  end;
  return v_existe;
exception  
  when others then
   raise_application_error(-20005,'Error al buscar Líneas de Sobregiro. Cuenta Nro='||p_nro_cuenta||' '||sqlerrm);  
end;

--Insertar línea de Sobregiro
procedure lp_ins_lin_sobregiro is

begin

    begin
       --Traer el Nro. de Secuencia--
       select s_nro_lin_sobregiro.nextval
         into v_nro_sec_padre
         from dual;
    exception
       when no_data_found then
          v_nro_sec_padre := 1;
       when others then
         raise_application_error(-20034,'Error al generar secuencia de sobregiro. Cuenta Nro='||p_nro_cuenta||' '||sqlerrm);
    end;
    --
    begin
      insert into cc_lin_sobregiros
        (nro_cuenta, fec_vencimiento, fec_inicio, nro_secuencia, monto, tipo, cod_persona, cod_moneda, estado, nro_sec_padre, observacion, niv_aprobacion)
      values
        (null, v_fecha, v_fec_vencimiento, v_nro_sec_padre, v_monto, 'T', p_cod_persona, v_cod_moneda, 'A', null, v_observacion, 7);
    exception
      when others then
        raise_application_error(-20035,'Error al insertar datos en CC_LIN_SOBREGIRO. SECUENCIA='||v_nro_sec_padre||' Cuenta: '||p_nro_cuenta||' '||sqlerrm);
    end;
    --
    begin
       --Traer el Nro. de Secuencia--
       select s_nro_lin_sobregiro.nextval
         into v_nro_secuencia
         from dual;
    exception
       when no_data_found then
          v_nro_secuencia := 1;
       when others then
         raise_application_error(-20034,'Error al generar secuencia de sobregiro. Cuenta Nro='||p_nro_cuenta||' '||sqlerrm);
    end;
    --
    begin
      insert into cc_lin_sobregiros
        (nro_cuenta, fec_vencimiento, fec_inicio, nro_secuencia, monto, tipo, cod_persona, cod_moneda, estado, nro_sec_padre, observacion, niv_aprobacion)
      values
        (p_nro_cuenta, v_fec_vencimiento, v_fecha, v_nro_secuencia, v_monto, 'T', null, v_cod_moneda, 'A', v_nro_sec_padre, v_observacion, 7);
    exception
      when others then
        raise_application_error(-20036,'Error al insertar datos en CC_LIN_SOBREGIRO. Cuenta Nro='||p_nro_cuenta||' '||sqlerrm);
    end;
    begin
      insert into cc_lin_sob_garantias
        (mto_aplicado, nro_secuencia, cod_garantia)
      values
        (v_monto, v_nro_sec_padre, 1);
    exception
      when others then
        raise_application_error(-20041,'Error al insertar datos en CC_LIN_SOB_GARANTIAS. Cuenta Nro='||p_nro_cuenta||' '||sqlerrm);
    end;

end lp_ins_lin_sobregiro;


begin

  --Traer Datos de la Cuenta
  select cod_modulo, cod_modalidad, cod_sub_modalidad, cod_moneda
    into v_cod_modulo,v_cod_modalidad,v_cod_sub_modalidad, v_cod_moneda
   from ge_cuentas
  where nro_cuenta = p_nro_cuenta;
  
  --Traer Descripción del paquete
  select c.descripcion
    into v_des_paquete
    from ge_paquetes c
   where c.cod_paquete = p_cod_paquete;
   
  v_observacion := 'Linea Sobg. '||v_des_paquete;

  --Traer Línea de Crédito de la tarjeta p/ el Cálculo de Línea de Sobregiro...
  begin
    select x.lin_credito
      into v_lin_tarjeta
      from ta_cta_tarjetas x
     where x.nro_cuenta in (select a.nro_cuenta
                              from ge_paq_cuentas a
                             where a.cod_paquete = p_cod_paquete
                               and a.cod_persona = p_cod_persona
                               and a.cod_modulo = 5);
   exception
     when no_data_found then
        v_lin_tarjeta := 0;
     when others then
        v_lin_tarjeta := 0;
   end;

  --Traer Porcentaje de Sobregiro
  v_porcentaje := fug_obt_pardinamico('POR_LIN_SOBREGIRO',v_cod_modulo,v_cod_modalidad,v_cod_moneda,null,v_cod_sub_modalidad);
  v_dias       := fug_obt_pardinamico('DIA_LIN_SOBREGIRO',v_cod_modulo,v_cod_modalidad,v_cod_moneda,null,v_cod_sub_modalidad);

  if lf_obt_lin_sobregiro(p_nro_cuenta,'T') = 'N' and nvl(v_porcentaje,0) > 0 and v_lin_tarjeta > 0 and nvl(v_dias,0) > 0 then

      --Cargar Variables para Línea de Sobregiro
      v_monto := round((v_lin_tarjeta*v_porcentaje)/100);
      v_fecha := pag_cal.fu_obt_fec_actual(4);
      v_fec_vencimiento := v_fecha + v_dias;

      lp_ins_lin_sobregiro;
      p_error := 'Línea de Sobregiro Generada con Exito, Nro. Cuenta: '||p_nro_cuenta||', Monto: '||to_char(v_monto,'999g999g999d99');
  end if;

end prg_gen_paq_sobregiros;
/

