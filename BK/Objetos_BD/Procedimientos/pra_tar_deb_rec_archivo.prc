CREATE OR REPLACE PROCEDURE IT.PRA_TAR_DEB_REC_ARCHIVO(p_registro        in varchar2,
                                                    p_cod_ente        in number,
                                                    p_nro_cuenta      out varchar2,
                                                    p_relacion        out varchar2,
                                                    p_nro_emision     out varchar2,
                                                    p_sucursal        out varchar2,
                                                    p_estado          out varchar2,
                                                    p_nom_embozado    out varchar2,
                                                    p_fec_vencimiento out varchar2,
                                                    p_nro_pin         out varchar2)
IS
-- Procedimiento que recupera los campos para la inserción en ah_tar_deb_pines,
-- haciendo el desglose según la entidad.
   --
  v_ente ge_entes.descripcion%type;
  v_nro_bin varchar2(6);
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
  --
begin

  -- Busca la descripción del Ente.
  begin
    select descripcion
      into v_ente
      from ge_entes
     where cod_ente = p_cod_ente;
  exception
    when others then
      raise_application_error(-20000,'Error al buscar el Ente '||sqlerrm);
  end;
  --Dependiendo del ente Arma los campos.
  if v_ente = 'BANCARD' then
    p_sucursal        := ltrim(rtrim(substr(p_registro,1,3)));                     --- sucursal
    v_nro_bin         := ltrim(rtrim(substr(p_registro,4,6)));                     --- nro de bin -- no se usa
   --Modificado 05/05/2009 WA- para que tome 10 Digitos del Nro de Cuenta
   --Acorde a Rediseño Formatos Archivo 1008 de Bancard
   -- v_nro_cuenta      := to_char(ltrim(rtrim(substr(p_registro,10,11))));    --- cuenta, tiene 7digitos
    v_nro_cuenta      := to_char(ltrim(rtrim(substr(p_registro,10,10))));    --- cuenta, tiene 7digitos   
    v_nro_cuenta      := FUA_VAL_CTA_INFONET(v_nro_cuenta, v_nro_bin);    -- SDBIN8TDD-1 se add nro_bin como parametro en la llamada
    p_relacion        := ltrim(rtrim(substr(p_registro,21,2)));                    ---    relación
    p_nro_emision     := ltrim(rtrim(substr(p_registro,23,2)));                    --- nro_emisión
    p_nom_embozado    := ltrim(rtrim(substr(p_registro,25,35)));                   --- nombre embozado
    p_fec_vencimiento := ltrim(rtrim(substr(p_registro,60,6)));--- fecha vencimiento
    p_nro_pin         := ltrim(rtrim(substr(p_registro,66,4)));        --- número pin
--    p_estado          := ltrim(rtrim(substr(p_registro,97,1)));                    --- fijo el estado
  elsif v_ente = 'BEPSA' then
    null;
  end if;
  --obtener la cuenta de ITGF a partir de la cuenta de infonet
  --Nro sucursal: 304
  --NRO BIN: 600691
  --NRO_CUENTA:00001132802
  --Relacion:00
  --Nro_emision:01
  --Nom_embozado:OSCAR PEREIRA GONZALEZ
  --Fecha Vto.: 201107
  --Nro Pin:8402
  --raise_application_error(-20009,'-->'|| p_registro  );
  --p_nro_cuenta := FUA_VAL_CTA_INFONET(v_nro_cuenta);
  p_nro_cuenta := v_nro_cuenta;

end PRA_TAR_DEB_REC_ARCHIVO;
/

