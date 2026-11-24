CREATE OR REPLACE TRIGGER IT.TB_AF_BIENES
 BEFORE UPDATE OR DELETE OR INSERT OR UPDATE
     ON AF_BIENES
    FOR EACH ROW
DECLARE
 v_fec_vto_depreciacion af_bienes.fec_vto_depreciacion%type;
 v_anos_deprecia        af_articulos.ano_depreciacion%type;
 v_ind_depreciacion     af_articulos.ind_depreciacion%type;
 v_anos_dep_acelerado   af_articulos.ano_dep_acelerado%type;
BEGIN
   ---
   if updating then
  
     select a.ind_depreciacion, a.ano_depreciacion, a.ano_dep_acelerado
     into   v_ind_depreciacion, v_anos_deprecia, v_anos_dep_acelerado
     from   af_articulos a
     where  a.cod_articulo = :new.cod_articulo;
     ---
     if v_ind_depreciacion = 'S' and nvl(v_anos_deprecia,0) > nvl(v_anos_dep_Acelerado,v_anos_deprecia) then
        v_fec_vto_depreciacion := ADD_MONTHS(:new.fec_compra, 12 * v_anos_dep_acelerado);
     elsif v_ind_depreciacion = 'S' and nvl(v_anos_deprecia,0) = nvl(v_anos_dep_Acelerado,v_anos_deprecia) then
        v_fec_vto_depreciacion := ADD_MONTHS(:new.fec_compra, 12 * v_anos_deprecia);
     else
        v_fec_vto_depreciacion := null;
     end if;
     :new.fec_vto_depreciacion := v_fec_vto_depreciacion;
   end if;
   ---
END;
/

