create or replace procedure it.PRP_OBT_LIBRADORES
                 (P_COD_BANCO IN NUMBER,
                  P_CTA_LIBRADORA IN VARCHAR2,
                  ---
                  P_ABR_DOCUMENTO1 IN OUT VARCHAR2,
                  P_NRO_DOCUMENTO1 IN OUT VARCHAR2,
                  P_NOM_COMPLETO1  IN OUT VARCHAR2,
                  P_LIS_NEGRA1     IN OUT VARCHAR2,
                  ---
                  P_ABR_DOCUMENTO2 IN OUT VARCHAR2,
                  P_NRO_DOCUMENTO2 IN OUT VARCHAR2,
                  P_NOM_COMPLETO2 IN OUT VARCHAR2,
                  P_LIS_NEGRA2     IN OUT VARCHAR2,
                  ---
                  P_ABR_DOCUMENTO3 IN OUT VARCHAR2,
                  P_NRO_DOCUMENTO3 IN OUT VARCHAR2,
                  P_NOM_COMPLETO3 IN OUT VARCHAR2,
                  P_LIS_NEGRA3     IN OUT VARCHAR2,
                  P_NOMBRE1 IN OUT VARCHAR2,
                  P_NOMBRE2 IN OUT VARCHAR2,
                  P_NOMBRE3 IN OUT VARCHAR2,
                  P_APELLIDO1 IN OUT VARCHAR2,
                  P_APELLIDO2 IN OUT VARCHAR2,
                  P_APELLIDO3 IN OUT VARCHAR2
                  ) is
  ----
  cursor c1 is Select distinct r.nro_documento , l.nom_completo , l.cod_tip_documento, d.abreviatura,
                      l.nombre, l.apellido
                 from ba_tip_documentos d, pr_chq_libradores l , pr_rel_chq_lib r
                where l.nro_documento     = r.nro_documento
                  and l.cod_tip_documento = r.cod_tip_documento
                  and r.cod_banco         = p_cod_banco
                  and r.cta_libradora     = p_cta_libradora
                  and l.cod_tip_documento = d.cod_tip_documento
                Order by 1;
  cursor c0 is Select distinct t.abreviatura, pe.nro_documento , pe.nom_completo, pe.cod_tip_documento, cc.cod_persona, cc.relacion,
                      pe.tipo
                 from ba_tip_documentos t, ba_personas pe, ge_cta_clientes cc, cc_cta_corrientes ct
                where t.cod_tip_documento = pe.cod_tip_documento
                  and pe.cod_persona      = cc.cod_persona
                  and cc.nro_cuenta       = ct.nro_cuenta
                  and ct.nro_cuenta       = p_cta_libradora
                Order by decode(cc.relacion, 'P', 1, 99);
  ----
  v_posicion number(3) := 1;
  v_cod_persona ba_personas.cod_persona%type;
  v_nombre ba_personas.nom_completo%type; --ba_per_fisicas.pri_nombre%type; --DYDMR-10508 - 19/02/2019
  v_apellido ba_per_fisicas.pri_apellido%type;
  ----
  function f_obt_cod_persona(p_cod_tip_documento ba_personas.cod_tip_documento%type, p_nro_documento ba_personas.nro_documento%type) Return varchar2 is
    v_cod_persona ba_personas.cod_persona%type;
  Begin
     Select cod_persona
       into v_cod_persona
       from ba_personas
      where cod_tip_documento = p_cod_tip_documento
        and nro_documento = p_nro_documento;
     Return v_cod_persona;
  Exception
     When NO_DATA_FOUND then return null;
  End;
begin
  --- Obtiene los datos de 3 libradores...
	If p_cta_libradora is not null Then
		If p_cod_banco = fug_obt_cod_banco and substr(pag_gen.fu_obt_cod_entidad,1,2) = 10 then
			  -- Es un banco y se cargo su codigo de banco.
		 For r1 in c0 Loop
         if r1.tipo = 'F' then
             begin
              select pri_nombre, pri_apellido
                into v_nombre, v_apellido
                from ba_per_fisicas
               where cod_persona = r1.cod_persona;
             exception 
               when others then
                 v_nombre := r1.nom_completo;
                 v_apellido := null;
             end;
         else
            v_nombre := r1.nom_completo;
            v_apellido := null;
         end if;           
		 		 If v_posicion = 1 Then
		 		 	  p_nro_documento1 := r1.nro_documento;
		 		 	  p_nom_completo1  := r1.nom_completo;
		 		 	  p_abr_documento1 := r1.abreviatura;
            p_nombre1   := v_nombre;
            p_apellido1 := v_apellido;
            --- Obtiene si es que está en lista negra o no...
            P_LIS_NEGRA1 := ' ';
            If FUG_OBT_FUE_PER_INHI(r1.cod_persona) = 'S' then
               P_LIS_NEGRA1 := 'M';
            End if;
		 		 Elsif v_posicion = 2 Then
		 		 	  p_nro_documento2 := r1.nro_documento;
		 		 	  p_nom_completo2  := r1.nom_completo;
		 		 	  p_abr_documento2 := r1.abreviatura;
            p_nombre2   := v_nombre;
            p_apellido2 := v_apellido;

            --- Obtiene si es que está en lista negra o no...
            P_LIS_NEGRA2 := ' ';
            If FUG_OBT_FUE_PER_INHI(r1.cod_persona) = 'S' then
               P_LIS_NEGRA2 := 'M';
            End if;
		 		 Else
		 		 	  p_nro_documento3 := r1.nro_documento;
		 		 	  p_nom_completo3  := r1.nom_completo;
		 		 	  p_abr_documento3 := r1.abreviatura;
            p_nombre3   := v_nombre;
            p_apellido3 := v_apellido;

            --- Obtiene si es que está en lista negra o no...
            P_LIS_NEGRA3 := ' ';
            If FUG_OBT_FUE_PER_INHI(r1.cod_persona) = 'S' then
               P_LIS_NEGRA3 := 'M';
            End if;
		 		 End If;
		 		 If v_posicion = 1 and pag_gen.fu_es_per_fisica(r1.cod_persona) != 'S' then
		 		 	  exit;
		 		 End if;
		 		 v_posicion := v_posicion + 1;
		 End Loop;
		Else
		 For r1 in c1 Loop
		 		 If v_posicion = 1 Then
		 		 	  p_nro_documento1 := r1.nro_documento;
		 		 	  p_nom_completo1  := r1.nom_completo;
		 		 	  p_abr_documento1 := r1.abreviatura;
            p_nombre1 := r1.nombre;
            p_apellido1 := r1.apellido;

            --- Obtiene si es que está en lista negra o no...
            v_cod_persona := f_obt_cod_persona(r1.cod_tip_documento, r1.nro_documento);
            P_LIS_NEGRA1 := ' ';
            If FUG_OBT_FUE_PER_INHI(v_cod_persona) = 'S' then
               P_LIS_NEGRA1 := 'M';
            End if;
		 		 Elsif v_posicion = 2 Then
		 		 	  p_nro_documento2 := r1.nro_documento;
		 		 	  p_nom_completo2  := r1.nom_completo;
		 		 	  p_abr_documento2 := r1.abreviatura;
            p_nombre2 := r1.nombre;
            p_apellido2 := r1.apellido;

            --- Obtiene si es que está en lista negra o no...
            v_cod_persona := f_obt_cod_persona(r1.cod_tip_documento, r1.nro_documento);
            P_LIS_NEGRA2 := ' ';
            If FUG_OBT_FUE_PER_INHI(v_cod_persona) = 'S' then
               P_LIS_NEGRA2 := 'M';
            End if;
		 		 Else
		 		 	  p_nro_documento3 := r1.nro_documento;
		 		 	  p_nom_completo3  := r1.nom_completo;
		 		 	  p_abr_documento3 := r1.abreviatura;
            p_nombre3 := r1.nombre;
            p_apellido3 := r1.apellido;

            --- Obtiene si es que está en lista negra o no...
            v_cod_persona := f_obt_cod_persona(r1.cod_tip_documento, r1.nro_documento);
            P_LIS_NEGRA3 := ' ';
            If FUG_OBT_FUE_PER_INHI(v_cod_persona) = 'S' then
               P_LIS_NEGRA3 := 'M';
            End if;
		 		 End If;
		 		 v_posicion := v_posicion + 1;
		 End Loop;
		End If;
	End If;
end PRP_OBT_LIBRADORES;
/

