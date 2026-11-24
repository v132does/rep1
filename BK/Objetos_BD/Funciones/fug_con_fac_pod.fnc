CREATE OR REPLACE FUNCTION IT.fug_con_fac_pod
   (P_COD_BANCO      IN       VARCHAR2,
    P_NRO_CUENTA     IN       VARCHAR2) RETURN typ_retornofacpod IS

   v_ret_dep       typ_retornofacpod := typ_retornofacpod();
   v_firmantes     typ_accountsigners := typ_accountsigners() ;
   v_element       number := 0;
   cursor firmantes is
      select t.cod_persona, p.nro_documento, p.nom_completo, p.cod_tip_documento, p.cod_pais,
      t.relacion signer_type, 
      it.fue_obt_sig_refcodes('RELACION',t.relacion) owner_ship_name, 
      it.fue_obt_val_max_referencia('RELACION',t.relacion) owner_ship_code, 
      p.tipo person_type
      from ge_cta_clientes t, ba_personas p
      where t.nro_cuenta = P_NRO_CUENTA
        and t.cod_persona = p.cod_persona
        ;
      
        
PROCEDURE lp_ins_log(p_respuesta   ge_log_con_fac_pod.respuesta%type,
                      p_error   ge_log_con_fac_pod.error%type
                      ) IS 
  pragma autonomous_transaction;
  BEGIN 
    
    INSERT INTO ge_log_con_fac_pod
      (cod_banco, nro_cuenta, respuesta, error
      )
    VALUES(P_cod_banco, p_nro_cuenta, p_respuesta, p_error
    );
    commit;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
 
BEGIN
   BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1;  END;
   
   begin
     select t.nro_cuenta, t.denominacion, 
        p.tipo type, 0 branch,
        ge.cod_usu_oficial EjcCod, fue_obt_nom_usuario(ge.cod_usu_oficial) EjcNom,
        ge.cod_seg_cliente SegCod, gs.descripcion SegNom
     into v_ret_dep.accountNumber, v_ret_dep.name, v_ret_dep.TYPE, v_ret_dep.branch,
          v_ret_dep.executiveCode, v_ret_dep.executiveName, v_ret_dep.segmentCode, v_ret_dep.segmentName
    from ge_cuentas t , ge_seg_clientes gs, ge_clientes ge, ge_cta_clientes g, ba_personas p
    where t.nro_cuenta = P_NRO_CUENTA
      and ge.cod_persona = g.cod_persona
      and g.nro_cuenta   = t.nro_cuenta
      AND g.relacion   = 'P'
      and gs.cod_seg_cliente = ge.cod_seg_cliente
      and p.cod_persona      = g.cod_persona;

   exception
      when no_data_found then
       lp_ins_log(null, 'Cuenta no existente.');
       return v_ret_dep;    
      when others then
       lp_ins_log(null, substr('Error al obtener la cuenta. '||SQLERRM,1,2000));
       return v_ret_dep;       
   end;
   
   for f in firmantes loop
     v_element := v_element + 1;
     v_firmantes.extend;
     v_firmantes(v_element) :=  typ_signers( f.cod_persona, f.nro_documento, f.nom_completo
         , f.cod_tip_documento, f.cod_pais, f.signer_type, f.owner_ship_name
         , f.owner_ship_code, f.person_type);
  
   end loop;
   lp_ins_log( utl_raw.cast_to_raw('accountNumber: '||v_ret_dep.accountNumber||' - name: ' ||v_ret_dep.name||' - type: '|| v_ret_dep.TYPE||' - branch: ' ||v_ret_dep.branch||
          ' - executiveCode: '||v_ret_dep.executiveCode||' - executiveName: '||' - executiveName: '|| v_ret_dep.executiveName||' - segmentCode: '|| v_ret_dep.segmentCode||' - segmentName: '|| v_ret_dep.segmentName) ,  null);
   v_ret_dep.accountSigners := v_firmantes;
   RETURN v_ret_dep;

EXCEPTION
   WHEN OTHERS THEN
   lp_ins_log(null, substr('Error en la función. '||SQLERRM,1,2000));
   RETURN v_ret_dep;
END;
/

