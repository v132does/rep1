CREATE OR REPLACE PROCEDURE IT.PRG_ACT_DAT_ATM (p_cod_persona in varchar2, p_dato in varchar2) is
v_existe varchar2(1);
v_fecha  date := pae_cnf.FU_OBT_FEC_ACTUAL(1);
v_dato   varchar2(100) := trim(p_dato);
v_tipo   varchar2(1) := 'A'; --telefono ATM
v_area   ba_telefonos.area%type;
v_telefono ba_telefonos.telefono%type;

function lf_ver_tip_telefono(p_cod_persona varchar2, p_area varchar2, p_telefono varchar2) 
 return varchar2 is
 v_existe varchar2(1);
begin
 select 'S'
   into v_existe
   from ba_act_dat_clientes a
  where a.cod_persona = p_cod_persona
    and a.tel_numero = p_telefono
    and a.tel_area = p_area
    and a.estado = 'R'
    and a.tel_tip_linea = 'C'
    and a.tip_solicitud = 'C';
    return v_existe;
exception
 when no_data_found then
   v_existe := 'N';
   return v_existe;
 when too_many_rows then
   v_existe := 'S';
   return v_existe;
 when others then
   v_existe := 'N';
   return v_existe;
end;

begin
  begin
    select 'S'
      into v_existe
      from ba_dat_atm a
     where a.cod_persona = p_cod_persona
       and a.valor = v_dato;
  exception
    when no_data_found then
      v_existe := 'N';
  end;
  v_area := substr(v_dato,1,4);
  v_telefono := substr(v_dato,5,6);
  if lf_ver_tip_telefono(p_cod_persona,v_area,v_telefono) = 'S' then
     v_tipo := 'H';
  else
     v_tipo := 'A';
  end if;
  if length(v_dato) = 10 then
    if v_existe = 'N' then --insertar
       insert into ba_dat_atm
              (cod_persona, tipo, valor, actualizado, fecha)
            values
              (p_cod_persona, v_tipo, v_dato, 'N',trunc(v_fecha));
    else --actualizar
       update ba_dat_atm a
          set a.valor = v_dato,
              a.actualizado = 'N',
              a.fecha = v_fecha
        where a.cod_persona = p_cod_persona
          and a.valor = v_dato; --el dato enviado
    end if;
  end if;
end prg_act_dat_atm;
/

