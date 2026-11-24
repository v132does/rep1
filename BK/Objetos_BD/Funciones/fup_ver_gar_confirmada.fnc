CREATE OR REPLACE FUNCTION IT.FUP_VER_GAR_CONFIRMADA
 (P_NRO_SOLICITUD IN NUMBER)
 RETURN BOOLEAN
 IS
  v_estado varchar2(1);
  v_confirmado boolean := true;
  CURSOR GARANTIAS is
   select b.estado
     from pr_sol_garantias a, pr_garantias b
    where a.nro_garantia = b.nro_garantia
      and a.nro_solicitud =p_nro_solicitud;
begin
   For gar in garantias loop
     if nvl(gar.estado,'X') ='C' then
        v_confirmado := true;
     else
        v_confirmado := false;
        return v_confirmado;
     end if;
   end loop;
   return v_confirmado;
exception
   when no_data_found then
      return true;
   when others then
      return false;
end;
/

