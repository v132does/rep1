create or replace procedure it.prp_obt_nom_librador (p_cod_tip_documento ba_tip_documentos.cod_tip_documento%type,
                                                  p_abr_tip_documento ba_tip_documentos.abreviatura%type,
                                                  p_nro_documento ba_personas.nro_documento%type,
                                                  p_nom_completo in out  ba_personas.nom_completo%type,
                                                  p_lis_negra in out varchar2) is
  v_cod_tip_documento ba_tip_documentos.cod_tip_documento%type;
  v_cod_persona       ba_personas.cod_persona%type;
Begin
  v_cod_tip_documento := p_cod_tip_documento;
  if p_cod_tip_documento is null and p_abr_tip_documento is not null then
     select cod_tip_documento
       into v_cod_tip_documento
       from ba_tip_documentos
      where abreviatura = p_abr_tip_documento;
  End if;
  Begin
    Select nom_completo, cod_persona
      into p_nom_completo, v_cod_persona
      from ba_personas
     where cod_tip_documento = v_cod_tip_documento
       and nro_documento = p_nro_documento;
    ---
    P_LIS_NEGRA := ' ';
    If FUG_OBT_FUE_PER_INHI(v_cod_persona) = 'S' then
       P_LIS_NEGRA := 'M';
    End if;
  Exception
     When NO_DATA_FOUND then
          Select nom_completo
            into p_nom_completo
            from pr_chq_libradores
           where cod_tip_documento = v_cod_tip_documento
             and nro_documento = p_nro_documento;
  End;
End;
/

