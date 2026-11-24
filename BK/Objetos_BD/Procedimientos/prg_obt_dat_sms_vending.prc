create or replace procedure it.PRG_OBT_DAT_SMS_VENDING(p_cod_persona in ba_personas.cod_persona%type,
                                                       p_envio_sms   out varchar2,
                                                       p_telefono    out varchar2,
                                                       p_texto       out varchar2,
                                                       p_cod_error   out number,
                                                       p_men_error   out varchar2) is
  v_envio_sms varchar2(1) := fug_obt_pardinamico('GEN_SMS_ACT_CU_VENDING');
  v_telefono  varchar2(30);
  v_nombre    varchar2(30);
  v_texto     varchar2(159) := fug_obt_pardinamico('GEN_SMS_CU_VENDING');
begin
  --se obtiene nro de telefono de cliente
  BEGIN
    select area || telefono
      into v_telefono
      from ba_telefonos
     where cod_persona = p_cod_persona
       and principal = 'S'
       and tip_linea = 'C';
  EXCEPTION
    when no_data_found then
      p_cod_error := 1;
      p_men_error := 'Numero de telefono principal no encontrado ';
    when too_many_rows then
      select area || telefono
        into v_telefono
        from ba_telefonos
       where cod_persona = p_cod_persona
         and principal = 'S'
         and tip_linea = 'C'
         and rownum = 1;
    when others then
      p_cod_error := 2;
      p_men_error := 'Error al buscar telefono. Persona ' || p_cod_persona || ' ' ||
                     sqlerrm;
  END;
  --se obtiene primer nombre de cliente
  BEGIN
    select pri_nombre
      into v_nombre
      from ba_per_fisicas
     where cod_persona = p_cod_persona;
  EXCEPTION
    when no_data_found then
      p_cod_error := 3;
      p_men_error := 'Primer nombre de cliente no encontrado ';
    when others then
      p_cod_error := 4;
      p_men_error := 'Error al buscar primer nombre. Persona ' ||
                     p_cod_persona || ' ' || sqlerrm;
  END;
  --en caso de que el nombre del cliente supere los 15 digitos, se debe cortar y guardar solo los 15 primeros
  v_nombre := SUBSTR(v_nombre, 0, 15);
  --se reemplaza 'primer nombre' definido en el parametro GEN_SMS_CU_VENDING
  v_texto := replace(v_texto, '(Primer nombre)', v_nombre);

  if v_envio_sms = 'S' then
    p_envio_sms := v_envio_sms;
    p_telefono  := v_telefono;
    p_texto     := v_texto;
  end if;
exception
  when others then
    p_envio_sms := null;
    p_telefono  := null;
    p_texto     := null;
    p_cod_error := 999;
    p_men_error := 'Error en proceso PR_OBT_DAT_SMS_VENDING ' || ' - ' ||
                   sqlerrm;
    prg_ins_log_programas('PR_OBT_DAT_SMS_VENDING',
                          p_men_error,
                          p_cod_persona,
                          null);
end PRG_OBT_DAT_SMS_VENDING;
/

