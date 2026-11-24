create or replace function it.FUP_OBT_PRI_PROPUESTA(p_nro_cuenta in varchar2)
  return varchar2 is
  v_nro_cuenta varchar2(15);
  v_cuenta     varchar2(15);
  v_tip_renovacion varchar2(1);
  existe number;
begin
   -- Verificar que la cuenta a consultas sea una renovacion, para que no entre en loop indefinido
   Select count(*) into existe
     from pr_Cta_prestamos
    where nro_cuenta = p_nro_cuenta
      and nvl(tip_renovacion,'A') <> 'A';
   If existe = 0 then
     return null;
   end if;
   --
   v_cuenta := p_nro_cuenta;
   Loop
     Select nro_cuenta, tip_renovacion
       into v_nro_cuenta, v_tip_Renovacion
       from pr_cta_prestamos
      where nro_cta_renovada = v_cuenta;
     if nvl(v_tip_renovacion,'A') = 'A' then  -- es la primera propuesta
       exit;
     else
       v_cuenta := v_nro_cuenta;
     end if;
   End loop;

  return(v_nro_cuenta);
exception
  when no_data_found then
    return v_cuenta; -- no encuentra primera propuesta,envía la última renovada
end FUP_OBT_PRI_PROPUESTA;
/

