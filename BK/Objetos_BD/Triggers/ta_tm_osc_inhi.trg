CREATE OR REPLACE TRIGGER IT.TA_TM_OSC_INHI
 AFTER INSERT ON "IT"."TM_OSC_INHI"
 FOR EACH ROW
DECLARE
v_cod_tip_documento   ba_tip_documentos.cod_tip_documento%type;
v_cod_persona					ba_personas.cod_persona%type;
v_tipo								ba_personas.tipo%type;
v_nom_completo				ba_personas.nom_completo%type;
v_ano									number(2);
v_fec_vencimiento			date;

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
      when no_data_found then
        v_cod_tip_documento := 999; -- otros
      when others then
         raise_application_error(-20000,'TA_TM_OSC_INHI: error al obtener cod_tip_documento en BA_TIP_DOCUMENTOS '||sqlerrm);
    end;

    --Chequeo si ya existe la persona en GF
    begin
        select cod_persona, tipo
        into v_cod_persona, v_tipo
        from ba_personas
        where cod_tip_documento = v_cod_tip_documento
        and nro_documento = :new.nro_documento;
    exception
      when no_data_found then
         v_cod_persona := null;
         v_tipo 			 := null;
      when others then
         raise_application_error(-20000,'TA_TM_OSC_INHI: error al obtener cod_persona en BA_PERSONAS '||sqlerrm);
    end;

    if v_cod_persona is not null then   -- Persona ya existe
        null;
    else
        insert into tm_osc_inhi_pendientes
          (nro_secuencia, nro_circular, ano_circular,
           codigo_banco, tipo_document, nro_documento, nombre1, nombre2, nombre3,
           apellido1, apellido2, apellido_casa, causal, multa,
           inhab_por, fecha_circula, moneda)
        values
          (:new.nro_secuencia, :new.nro_circular, :new.ano_circular, :new.codigo_banco,
           :new.tipo_document, :new.nro_documento, :new.nombre1, :new.nombre2, :new.nombre3,
           :new.apellido1, :new.apellido2, :new.apellido_casa, :new.causal, :new.multa,
           :new.inhab_por, :new.fecha_circula, :new.moneda);
    /*  -- Persona no existe, Cargar los datos
				-- Obtener el siguiente codigo de persona valido en GF
        select s_cod_persona.nextval into v_cod_persona from dual;

				--Si es persona Juridica se registra por RUC, si es fisica por CI
				if v_cod_tip_documento = 6 then
    				v_tipo := 'J';
				else
    				v_tipo := 'F';
				end if;

        v_nom_completo := substr(:new.nombre1||' '||:new.nombre2||' '||:new.nombre3||' '||
											 		:new.apellido1||' '||:new.apellido2||' '||:new.apellido_casa,1,120);

        --Insercion de BA_PERSONAS
				insert into ba_personas
        (cod_persona, nom_completo, tipo,
				cod_tip_documento, nro_documento, cod_pais,
				est_verificacion, obs_verificacion, fec_verificacion, fec_vto_documento )
        values
        (v_cod_persona, v_nom_completo, v_tipo,
        v_cod_tip_documento, :new.nro_documento, 1,--Pais 1= Paraguay
				'V', 'DATOS DE OSC', sysdate, sysdate );--Se agrega fec_vto_documento porque controla en el trigger tb_ba_personas

        --Inserci¿n de BA_PER_FICICAS / BA_PER_JURIDICAS
				if v_tipo = 'J' then -- Es persona Juridica
            insert into ba_per_juridicas
            (cod_persona, raz_social, nom_comercial)
            values
            (v_cod_persona, :new.nombre1, substr(:new.nombre1,1,65));
        else -- Es persona Fisica
            insert into ba_per_fisicas
            (cod_persona, pri_nombre,
						seg_nombre, pri_apellido,
						seg_apellido, est_civil, cod_sexo)
            values
            (v_cod_persona, substr(:new.nombre1,1,30),
						substr(:new.nombre2||' '||:new.nombre3,1,30), nvl(:new.apellido1,'SIN APELLIDO'),
						nvl(substr(:new.apellido2||' '||:new.apellido_casa,1,30),'SIN APELLIDO'),
            decode(:new.apellido_casa,null,'S','C'),'M');
        end if;*/
		end if;

		--Variable auxiliar para saber cuantos a¿os debo sumar a la fecha de circular
		if to_number(:new.inhab_por) = 10 then
    		v_ano := 1;
		else
    		v_ano := 10;
		end if;

		v_fec_vencimiento := to_date(substr(:new.fecha_circula,1,4)||to_char(to_number(substr(:new.fecha_circula,5,4))+v_ano),'ddmmyyyy');

    -- Actualizo las inhibiciones, si existe
    update ge_per_inhibidas a set
        cod_causa = decode(to_number(:new.inhab_por),10,21,22),
        fec_inicio =  to_date(:new.fecha_circula,'ddmmyyyy'),
        fec_vencimiento = v_fec_vencimiento,
        origen = 'BANCO CENTRAL DEL PARAGUAY',
        cod_banco = to_number(substr(:new.codigo_banco,3)),
        nro_cta_inhibida = null,
        mto_multa = to_number(:new.multa),
        referencia = null,
        detalle = ' Inhabilitado por '||v_ano||' a¿os.'||chr(10)||
                  ' Circular: A¿o: '||:new.ano_circular||' Nro: '||:new.nro_circular||
                  ' Sec.: '||:new.nro_secuencia||' Moneda: '||:new.moneda,
        usu_modificacion = user,
        fec_modificacion = sysdate
     where cod_persona = v_cod_persona
       and nro_orden = to_number(:new.nro_secuencia);


		if sql%notfound then
      if v_cod_persona is not null then  --se agrega la validacion para que la persona pueda entrar entre los pendientes NVB-218
       -- no esta en inhibidos
       insert into ge_per_inhibidas
           (cod_persona,
            nro_orden ,
            cod_causa ,
            fec_inicio,
            fec_vencimiento,
            origen,
            cod_banco,
            nro_cta_inhibida,
            mto_multa,
            referencia,
            detalle,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion,
						estado)
        values
          (v_cod_persona,
           to_number(:new.nro_secuencia),
           decode(to_number(:new.inhab_por),10,21,22),
					 to_date(:new.fecha_circula,'ddmmyyyy'),
           v_fec_vencimiento,
           'BANCO CENTRAL DEL PARAGUAY',
            substr(:new.codigo_banco,3),
            null,
            to_number(:new.multa),
            null,
            ' Inhabilitado por '||v_ano||' a¿os.'||chr(10)||
            ' Circular: A¿o: '||:new.ano_circular||' Nro: '||:new.nro_circular||
            ' Sec.: '||:new.nro_secuencia||' Moneda: '||:new.moneda,
            user,
            sysdate,
            user,
            sysdate,
						'I');
       end if;
   end if;

	 --Cargar la tabla para interfaz
   /* anulada porque no existe tabla de interfaz
	 begin
      insert into in_oso_ainhibic
       (nro_circular, ano_circular, nro_secuencia, codigo_banco,
			 tipo_documento, nro_documento,  nombre1, nombre2, nombre3,
			 apellido1, apellido2, apellido_casad, causal, multa, inhab_por,
			 fecha_circular, moneda, added_by, changed_by, date_added,
			 date_changed, fecha_caducac)
			 values
			 (:new.nro_circular, :new.ano_circular, :new.nro_secuencia, :new.codigo_banco,
        :new.tipo_document, :new.nro_documento, :new.nombre1, :new.nombre2, :new.nombre3,
				:new.apellido1, :new.apellido2, :new.apellido_casa, :new.causal, :new.multa, :new.inhab_por,
				:new.fecha_circula, :new.moneda, user, user, to_char(sysdate,'yyyymmdd'),
				to_char(sysdate,'yyyymmdd'), to_char(v_fec_vencimiento,'yyyymmdd'));
	 end;
   */ 
EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20000,' TA_TM_OSC_INHI: error actualizando inhibiciones '||:new.nro_documento||' - ' ||sqlerrm);
END;
/

