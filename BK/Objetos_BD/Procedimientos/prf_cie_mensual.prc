CREATE OR REPLACE PROCEDURE IT.PRF_CIE_MENSUAL
is

v_fec_proceso af_bienes.fec_proceso%type;
v_tipo        af_coe_revaluos.tipo%type;

begin
	begin
		select max(fec_proceso), max(tipo)
		into v_fec_proceso, v_tipo
		from af_coe_revaluos
		where ind_procesado = 'N';
  if v_fec_proceso is null then
     raise_application_error(-20000, 'No existe registro de Coeficiente cargado pendiente de Proceso. Verifique. ' || sqlerrm);
  end if;
	exception
		when no_data_found then
			raise_application_error(-20000, ' No existe coeficiente ' || sqlerrm);
		when others then
			raise_application_error(-20000, ' Error al obtener coeficiente ' || sqlerrm);
	end;
	prf_cie_revaluo(v_fec_proceso,v_tipo);
end;
/

