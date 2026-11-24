create or replace function it.fug_es_cta_cobit(P_NRO_CUENTA IN VARCHAR2
) return varchar2 is
--Retorna(Si es una cuenta COVID no reversada - Activa):
   --CA Corresponde a cuenta cancelada
   --NU Corresponde a Cuenta Nueva Creada
   --NO  No corresponde a Cobit
  v_respuesta VARCHAR2(10) := 'NO';
  v_cantidad  number(10);
begin
  v_cantidad:= 0;
  -- Verifico si existe en la tabla uno a uno
  begin
      Select nvl(count(*),0)
        into v_cantidad
          from PR_CTA_PRE_REF_RES4 a
           where a.nro_cuenta= P_NRO_CUENTA
            and nvl(a.reversado,'N')='N'
            and NVL(a.inventariar,'N')='S';
   exception
     when no_data_found then
         v_cantidad:= 0;
     when others then
         v_cantidad:= 0;
   end;

   if v_cantidad > 0 then
     v_respuesta:= 'CA';
   else
       -- Verificamos si es una cuenta nueva
       begin
          Select nvl(count(*),0)
            into v_cantidad
              from PR_CTA_PRE_REF_RES4 a
               where a.nro_cta_nueva= P_NRO_CUENTA
                and nvl(a.reversado,'N')='N'
                and NVL(a.inventariar,'N')='S';
       exception
         when no_data_found then
             v_cantidad:= 0;
         when others then
             v_cantidad:= 0;
       end;

         if v_cantidad > 0 then
            v_respuesta:= 'NU';
         else
             --Verificamos en Masivo Canceladas
             begin
                  Select nvl(count(*),0)
                    into v_cantidad
                      from PR_CTA_PRE_CAN_RES4 a
                       where a.nro_cuenta= P_NRO_CUENTA
                        and nvl(a.reversado,'N')='N'
                        and NVL(a.inventariar,'N')='S';
               exception
                 when no_data_found then
                     v_cantidad:= 0;
                 when others then
                     v_cantidad:= 0;
               end;
                if v_cantidad > 0 then
                   v_respuesta:= 'CA';
                else
                      --Verificamos en Masivo Nueva
                     begin
                        Select nvl(count(*),0)
                          into v_cantidad
                            from PR_CTA_PRE_CAN_RES4 a
                             where a.nro_cta_nueva= P_NRO_CUENTA
                              and nvl(a.reversado,'N')='N'
                              and NVL(a.inventariar,'N')='S';
                     exception
                       when no_data_found then
                           v_cantidad:= 0;
                       when others then
                           v_cantidad:= 0;
                     end;
                      if v_cantidad > 0 then
                        v_respuesta:= 'NU';
                      else
                        v_respuesta:= 'NO';
                      END IF;
                end if;
         end if;
   end if;


   return(v_respuesta);

exception
  when no_data_found then
     return ('N');
  when others then
     raise_application_error(-20000,'fug_es_cta_cobit '||sqlerrm);
end fug_es_cta_cobit;
/

