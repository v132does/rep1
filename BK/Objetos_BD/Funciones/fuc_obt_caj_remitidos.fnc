create or replace function it.fuc_obt_caj_remitidos
 (p_nro_cuenta in varchar2
 )
 return number
 is
   v_longitud       number;
   v_nro_caja_aux   varchar2(3);
   v_nro_caja       cj_cajas.nro_caja%type;
begin

   v_longitud    := length(to_number(p_nro_cuenta));
   v_nro_caja_aux := substr(to_number(p_nro_cuenta),2,3);
   
   /*
   begin
     --Verificar si existe Nro. de Caja
     select c.nro_caja
       into v_nro_caja
       from cj_cajas c
      where c.nro_caja = v_nro_caja_aux;
   exception
     when no_data_found then
       --v_nro_caja := null;
       v_nro_caja := v_nro_caja_aux;
   end;
   */
   v_nro_caja := nvl(v_nro_caja_aux,1);
 
   return v_nro_caja;

exception
   when others then
     if sqlcode < -20000  then
         raise;
     else
        raise_application_error(-20000,'Error en FUC_OBT_CAJ_REMITIDOS : ' || sqlerrm);
     end if;
end fuc_obt_caj_remitidos;
/

