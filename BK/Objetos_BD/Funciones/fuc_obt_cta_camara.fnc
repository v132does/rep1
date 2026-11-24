CREATE OR REPLACE FUNCTION IT.FUC_OBT_CTA_CAMARA
 (p_nro_cuenta in varchar2
 )
 return varchar2
 is
 v_nro_cuenta  ge_cuentas.nro_cuenta%type;

begin
   --Se utiliza para convertir la cuenta que viene en el archivo de Recibidos (Cidesa)
   v_nro_cuenta := fuc_obt_cta_cmc7(p_nro_cuenta);

   --Si es un Cheque Gerencia Buscar la Cta. para la Oficina
   if substr(v_nro_cuenta,3,8) ='52000040' then
     begin
        select x.nro_cuenta
          into v_nro_cuenta
          from cc_cta_bancarias x
         where x.cod_modalidad = 43
           and x.cod_oficina = substr(v_nro_cuenta,1,2)
           and x.cod_moneda = pag_gen.fu_obt_mon_local;
      exception
        when others then
          null;
      end;
   end if;

   return v_nro_cuenta;

end;
/

