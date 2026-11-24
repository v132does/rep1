CREATE OR REPLACE TRIGGER IT.TA_TM_OSC_REHA
 AFTER INSERT ON TM_OSC_REHA
 FOR EACH ROW
DECLARE
v_cod_tip_documento   ba_tip_documentos.cod_tip_documento%type;
v_cod_persona					ba_personas.cod_persona%type;
v_detalle							ge_per_inhibidas.detalle%type;
v_posicion						number(3);


--Se define el cursor porque puede registrarse mas de una inhibicion para
--la misma persona
CURSOR cuentas IS
SELECT cod_persona, detalle, nro_orden
FROM ge_per_inhibidas
WHERE cod_causa in (21,22);--Solo inhibiciones de OSC

BEGIN
	  v_cod_tip_documento := null;

    -- Busco el tipo de documento
    begin
        select cod_tip_documento
				into v_cod_tip_documento
        from ba_tip_documentos a
        where abreviatura = :new.tipo_document
				and estado = 'A'
				and rownum = 1;
    exception
      when others then
         raise_application_error(-20000,'TA_TM_OSC_REHA: error al obtener cod_tip_documento en BA_TIP_DOCUMENTOS '||sqlerrm);
    end;

    --Obtener el codigo de persona
    begin
        select cod_persona
        into v_cod_persona
        from ba_personas
        where cod_tip_documento = v_cod_tip_documento
        and nro_documento = :new.nro_documento;
    exception
      when others then
				 v_cod_persona := null;
    end;

		--Armo el detalle que debe ser guardado
		v_detalle :=' Rehabilitado en fecha: '||:new.fecha_circula||
                  ' Circular: Año: '||:new.ano_circular||' Nro: '||:new.nro_circular||
                  ' Sec.: '||:new.nro_secuencia;

		--Recorrer	las inhibiciones de la persona para chequear si corresponde grabar el detalle
		for ctas in cuentas loop
    		begin
    				if ctas.cod_persona = v_cod_persona then
    						v_posicion := instr(ctas.detalle,v_detalle);
    						if v_posicion = 0 then--Si el detalle no existe
                    -- Actualizo las inhibiciones
                      update ge_per_inhibidas set
                      estado = 'D',
                      detalle = detalle||chr(10)||v_detalle
                      where cod_persona = v_cod_persona
											and nro_orden = ctas.nro_orden;

                    if sql%notfound then
                          it_mail.mail(fug_obt_dir_correo,
                          'warevalos@itbank.com.py',
                          'Problemas en el Proceso de DESINHIBICION ',
                          'No se pudo DESINHIBIR la persona cuyos datos se detallan mas abajo: '||CHR(10)||
                          'Documento: '||to_char(:new.nro_documento)||' '||:new.nombre1||' '||:new.apellido1||chr(10)||
                          ' Circular: Año: '||:new.ano_circular||' Nro: '||:new.nro_circular||
                          ' Sec.: '||:new.nro_secuencia||sqlerrm);
                    end if;
    						end if;
    				end if;
    		end;
		end loop;

		--Cargar la tabla para interfaz
    /* anulada porque no existe tabla de interfaz
		begin
        insert into in_oso_arehabic
        (nro_circular, ano_circular, nro_secuencia, codigo_banco, 
        tipo_documento, nro_documento, nombre1, nombre2, 
        nombre3, apellido1, apellido2, apellido_casad, 
        fecha_circular, date_add, user_add)
        values
				(:new.nro_circular, :new.ano_circular, :new.nro_secuencia, :new.codigo_banco, 
				:new.tipo_document, :new.nro_documento, :new.nombre1, :new.nombre2, 
				:new.nombre3, :new.apellido1, :new.apellido2, :new.apellido_casa,
				:new.fecha_circula, to_char(sysdate,'yyyymmdd'),user);
		end;
    */
EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20000,' TA_TM_OSC_REHA: error intentando desinhibir, DOCUMENTO NRO: '||:new.nro_documento||' - ' ||sqlerrm);
END;
/

