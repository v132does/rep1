CREATE OR REPLACE FUNCTION IT.FUY_OBT_DES_CG_REF
 (P_RV_DOMAIN VARCHAR2
 ,P_LOW_VALUE VARCHAR2
 )
 RETURN VARCHAR2
 IS
begin
declare
   v_descripcion cg_ref_codes.rv_abbreviation%type;

begin

   select rv_abbreviation
   into v_descripcion
   from cg_ref_codes
   where rv_domain = upper(p_rv_domain)
   and rv_low_value = upper(p_low_value);

   RETURN v_descripcion;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Dominio/Valores'||p_rv_domain||' no registrado');

end;
end;
/

