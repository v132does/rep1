CREATE OR REPLACE PROCEDURE IT.prg_pro_cam_oficina IS

  v_gen_pro_cam_ofi_cuentas varchar(1) := fug_obt_pardinamico('GEN_PRO_CAM_OFI_CUENTAS');
  -- Fecha: 30/06/2016.
  -- Requerimiento: CNFDEEVO-47.
  v_cod_ofi_tesoreria       ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_OFI_TESORERIA');
  
  PROCEDURE lp_act_ofi_cta_cda_bonos IS
    v_fec_proceso date          := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_anho        varchar2(4)   := to_char(v_fec_proceso,'yyyy');
    v_mes         varchar2(2)   := to_char(v_fec_proceso,'mm');
    v_contador    number(5)     := 0 ;
                  
    cursor c_datos is
      -- Fecha: 30/06/2016.
      -- Requerimiento: CNFDEEVO-47.
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_certificados a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X')                 
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'N'
               order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      union all
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, v_cod_ofi_tesoreria nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_certificados a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X')                 
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'S'
               order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;  
      
  begin
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;  
      
    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_ah_cta_certificados disable');
    EXECUTE IMMEDIATE ('alter trigger ta_ah_cta_certificados disable');
  
    -- Actualizo las tablas.
    for reg in c_datos loop
            
      Begin
        v_contador := v_contador + 1 ;

        -- Actualizo las tablas maestras de cuentas.
        update ge_cta_clientes gc
           set gc.cod_oficina = reg.nvo_oficina
         where gc.nro_cuenta = reg.nro_cuenta;
          
        update ge_cuentas gcc
           set gcc.cod_oficina = reg.nvo_oficina
         where gcc.nro_cuenta = reg.nro_cuenta;
          
        -- Actualizo la tabla maestra de CDA & Bonos Subordinados.
        update ah_cta_certificados ah
           set ah.cod_oficina = reg.nvo_oficina
         where ah.nro_cuenta = reg.nro_cuenta;
          
        -- Actualizo las tablas historicas.
        update ah_sal_mensuales am
           set am.cod_oficina = reg.nvo_oficina
         where am.nro_cuenta = reg.nro_cuenta
           and am.ano = v_anho
           and am.mes = v_mes;
           
        update ah_devengados_his ad
           set ad.cod_oficina = reg.nvo_oficina
         where ad.nro_cuenta = reg.nro_cuenta
           and ad.ano = v_anho
           and ad.mes = v_mes;
                 
      exception
        when others then
          null;     
      end;
        
      if v_contador = 100 then
        --commit ;
        v_contador := 0 ;
      end if ;
    end loop;  
      
    --commit ;

    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_ah_cta_certificados enable');
    EXECUTE IMMEDIATE ('alter trigger ta_ah_cta_certificados enable');  
  end;

  PROCEDURE lp_act_ofi_cta_ahorro IS
    v_fec_proceso date        := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_anho        varchar2(4) := to_char(v_fec_proceso,'yyyy');
    v_mes         varchar2(2) := to_char(v_fec_proceso,'mm');
    v_contador    number(5)   := 0 ;

    cursor c_datos is
      -- Fecha: 30/06/2016.
      -- Requerimiento: CNFDEEVO-47.
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_vistas a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X','P')
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'N'
                order by b.cod_persona) v
              where v.nvo_oficina != v.cod_oficina
       union all
       select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, v_cod_ofi_tesoreria nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_vistas a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X','P')
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'S'
                order by b.cod_persona) v
              where v.nvo_oficina != v.cod_oficina;  
      
  begin

    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_ah_cta_vistas disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
     v_contador := v_contador + 1 ;  
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta = reg.nro_cuenta;
         
       update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta = reg.nro_cuenta;
          
      -- Actualizo la tabla maestra.
      update ah_cta_vistas ah
         set ah.cod_oficina = reg.nvo_oficina
       where ah.nro_cuenta = reg.nro_cuenta;
         
      -- Actualizo la tabla maestra.
      update ah_cta_vistas_noc ah
         set ah.cod_oficina = reg.nvo_oficina
       where ah.nro_cuenta = reg.nro_cuenta;
         
      -- Actualizo las tablas historicas.
      update ah_sal_mensuales am
         set am.cod_oficina = reg.nvo_oficina
       where am.nro_cuenta = reg.nro_cuenta
         and am.ano = v_anho
         and am.mes = v_mes;
           
      update ah_devengados_his ad
         set ad.cod_oficina = reg.nvo_oficina
       where ad.nro_cuenta = reg.nro_cuenta
         and ad.ano = v_anho
         and ad.mes = v_mes;
           
      update ah_retenciones ar
         set ar.cod_oficina = reg.nvo_oficina
       where ar.nro_cuenta = reg.nro_cuenta
         and ar.liberado = 'N';
           
      -- Actualiza la tabla de movimientos nocturnos.
      update ge_movimientos_noc ge
         set ge.cod_oficina = reg.nvo_oficina
       where ge.nro_cuenta = reg.nro_cuenta;
    	 
    -- Actualiza la tabla historica de movimientos del mes
    update ah_movimientos_his ge
         set ge.cod_oficina = reg.nvo_oficina
       where ge.nro_cuenta  = reg.nro_cuenta
       and ge.fecha       >= TRUNC(v_fec_proceso,'MM');
                 
     exception
        when others then
           null;     
     end;

    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop; 
    --commit ;  
      
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_ah_cta_vistas enable');  
  end;

  PROCEDURE lp_act_ofi_cta_cta_corriente IS
    v_fec_proceso date        := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_anho        varchar2(4) := to_char(v_fec_proceso,'yyyy');
    v_mes         varchar2(2) := to_char(v_fec_proceso,'mm');
    v_contador    number(5)   := 0 ;
    cursor c_datos is
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cc_cta_corrientes a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('C','X','P')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;  
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cc_cta_corrientes disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
     v_contador := v_contador + 1 ;
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta = reg.nro_cuenta;
         
       update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta = reg.nro_cuenta;
          
      -- Actualizo la tabla maestra.
      update cc_cta_corrientes cc
         set cc.cod_oficina = reg.nvo_oficina
       where cc.nro_cuenta = reg.nro_cuenta;
         
      -- Actualizo la tabla maestra.
      update cc_cta_corrientes_noc cn
         set cn.cod_oficina = reg.nvo_oficina
       where cn.nro_cuenta = reg.nro_cuenta;
         
      -- Actualizo las tablas historicas.
      update cc_sal_mensuales cs
         set cs.cod_oficina = reg.nvo_oficina
       where cs.nro_cuenta = reg.nro_cuenta
         and cs.ano = v_anho
         and cs.mes = v_mes;
           
      update ah_retenciones ar
         set ar.cod_oficina = reg.nvo_oficina
       where ar.nro_cuenta = reg.nro_cuenta
         and ar.liberado = 'N';
           
      -- Actualiza la tabla de movimientos nocturnos.
      update ge_movimientos_noc ge
         set ge.cod_oficina = reg.nvo_oficina
       where ge.nro_cuenta = reg.nro_cuenta;
    	 
     -- Actualiza la tabla de movimientos historicos.
      update cc_movimientos_his ge
         set ge.cod_oficina = reg.nvo_oficina
       where ge.nro_cuenta  = reg.nro_cuenta
       and ge.fecha 	  >= TRUNC(v_fec_proceso,'MM');
                 
     exception
        when others then
           null;     
     end; 
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
      
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cc_cta_corrientes enable');
  end;


  PROCEDURE lp_act_ofi_cta_tarjetas IS
    v_fec_proceso date        := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_anho        varchar2(4) := to_char(v_fec_proceso,'yyyy');
    v_mes         varchar2(2) := to_char(v_fec_proceso,'mm');
    v_contador    number(5)   := 0 ;
    cursor c_datos is
     select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from ta_cta_tarjetas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('A','C')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;   
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
      
    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger ab_ta_cta_tarjetas disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
     v_contador := v_contador + 1 ;  
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
     update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
    update ta_cta_tarjetas ta
       set ta.cod_oficina = reg.nvo_oficina
     where ta.nro_cuenta  = reg.nro_cuenta;
         
      -- Actualizo las tablas historicas. 
      update ta_sal_mensuales sm
         set sm.cod_oficina = reg.nvo_oficina
       where sm.nro_cuenta  = reg.nro_cuenta
         and sm.ano = v_anho
         and sm.mes = v_mes; 
         
     -- Actualiza la tabla de movimientos historicos de tarjetas.
      update ta_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
    	  
     exception
        when others then
           null;     
     end;    
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger ab_ta_cta_tarjetas enable');
  end;

  PROCEDURE lp_act_ofi_cta_prestamos IS
    v_fec_proceso date        := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_anho        varchar2(4) := to_char(v_fec_proceso,'yyyy');
    v_mes         varchar2(2) := to_char(v_fec_proceso,'mm');
    v_contador    number(5)   := 0 ;
    cursor c_datos is
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from pr_cta_prestamos a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('N','I')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;  
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_pr_cta_prestamos disable');
    EXECUTE IMMEDIATE ('alter trigger ta_pr_cta_prestamos disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
      v_contador := v_contador + 1 ;  
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
       update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
      update pr_cta_prestamos cc
         set cc.cod_oficina = reg.nvo_oficina
       where cc.nro_cuenta  = reg.nro_cuenta;
         
      -- Actualizo las tablas historicas.
      update pr_sal_mensuales ps
         set ps.cod_oficina = reg.nvo_oficina
       where ps.nro_cuenta = reg.nro_cuenta
         and ps.ano = v_anho
         and ps.mes = v_mes;
    	   
    update pr_devengados_his hs
         set hs.cod_oficina = reg.nvo_oficina
       where hs.nro_cuenta = reg.nro_cuenta
         and hs.ano = v_anho
         and hs.mes = v_mes; 
    	   
    update pr_gastos_cob gc
         set gc.cod_oficina = reg.nvo_oficina
       where gc.nro_cuenta = reg.nro_cuenta;     
         
     -- Actualiza la tabla de movimientos historicos.
      update pr_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
                 
     exception
        when others then
           null;     
     end;    
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_pr_cta_prestamos enable');
    EXECUTE IMMEDIATE ('alter trigger ta_pr_cta_prestamos enable');
  end;

  PROCEDURE lp_act_ofi_cta_ope_vencidas IS
    v_fec_proceso date        := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_anho        varchar2(4) := to_char(v_fec_proceso,'yyyy');
    v_mes         varchar2(2) := to_char(v_fec_proceso,'mm');
    v_contador    number(5)   := 0 ;
    cursor c_datos is
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from ov_cta_vencidas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('C','I')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;  
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger ta_ov_cta_vencidas disable');
    EXECUTE IMMEDIATE ('alter trigger ab_ov_cta_vencidas disable');
    EXECUTE IMMEDIATE ('alter trigger ab_ov_sal_mensuales disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
     v_contador := v_contador + 1 ;  
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
       update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
      update ov_cta_vencidas cc
         set cc.cod_oficina = reg.nvo_oficina
       where cc.nro_cuenta  = reg.nro_cuenta;
         
      -- Actualizo las tablas historicas.
      update ov_sal_mensuales ps
         set ps.cod_oficina = reg.nvo_oficina
       where ps.nro_cuenta = reg.nro_cuenta
         and ps.ano = v_anho
         and ps.mes = v_mes;
    	          
      -- Actualiza la tabla de movimientos historicos.
      update ov_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
                 
     exception
        when others then
           null;     
     end; 
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger ta_ov_cta_vencidas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_ov_cta_vencidas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_ov_sal_mensuales enable');
  end;

  PROCEDURE lp_act_ofi_cta_cx_cta_cobran IS
    v_fec_proceso date := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_contador    number(5)   := 0 ;
    cursor c_datos is
     select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_cta_cobranzas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('83','84')
         and a.estado NOT IN ('C','R','G')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;    
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_cobranzas disable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_cobranzas disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
     v_contador := v_contador + 1 ;  
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
     update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
    update cx_cta_cobranzas a
       set a.cod_oficina = reg.nvo_oficina
     where a.nro_cuenta  = reg.nro_cuenta;
        
    -- Actualiza la tabla de movimientos historicos de comex.
      update cx_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
    	  
     exception
        when others then
           null;     
     end; 
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_cobranzas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_cobranzas enable');
  end;

  PROCEDURE lp_act_ofi_cta_cx_cta_export IS
    v_fec_proceso date := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_contador    number(5)   := 0 ;
    cursor c_datos is
     select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_cta_exportaciones a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('82')
         and a.estado NOT IN ('C','R','G','U')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;    
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_exportaciones disable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_exportaciones disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
      v_contador := v_contador + 1 ; 
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
     update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
    update cx_cta_exportaciones a
       set a.cod_oficina = reg.nvo_oficina
     where a.nro_cuenta  = reg.nro_cuenta;
        
    -- Actualiza la tabla de movimientos historicos de comex.
      update cx_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
    	  
     exception
        when others then
           null;     
     end;  
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_exportaciones enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_exportaciones enable');
  end;

  PROCEDURE lp_act_ofi_cta_cx_cta_import IS
    v_fec_proceso date := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_contador    number(5)   := 0 ;
    cursor c_datos is
     select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_cta_importaciones a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('81')
         and a.estado NOT IN ('C','R','G','U')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;    
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_importaciones disable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_importaciones disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
       v_contador := v_contador + 1 ;
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
     update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
    update cx_cta_importaciones a
       set a.cod_oficina = reg.nvo_oficina
     where a.nro_cuenta  = reg.nro_cuenta;
        
    -- Actualiza la tabla de movimientos historicos de comex.
      update cx_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
    	  
     exception
        when others then
           null;     
     end;  
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_importaciones enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_importaciones enable');
  end;

  PROCEDURE lp_act_ofi_cta_cx_fianzas IS
    v_fec_proceso date := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_contador    number(5)   := 0 ;
    cursor c_datos is
     select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_fianzas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('88')
         and a.estado NOT IN ('C')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;    
      
  begin
      
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

    -- Desactivo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_fianzas disable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_fianzas disable');
      
    -- Actualizo las tablas.
    for reg in c_datos loop
       v_contador := v_contador + 1 ;
     Begin
         
       -- Actualizo las tablas maestras de cuentas.
     update ge_cuentas gcc
          set gcc.cod_oficina = reg.nvo_oficina
        where gcc.nro_cuenta  = reg.nro_cuenta;
    	  
       update ge_cta_clientes gc
          set gc.cod_oficina = reg.nvo_oficina
        where gc.nro_cuenta  = reg.nro_cuenta;  
          
      -- Actualizo la tabla maestra.
    update cx_fianzas a
       set a.cod_oficina = reg.nvo_oficina
     where a.nro_cuenta  = reg.nro_cuenta;
        
    -- Actualiza la tabla de movimientos historicos de comex.
      update cx_movimientos_his hi
         set hi.cod_oficina = reg.nvo_oficina
       where hi.nro_cuenta  = reg.nro_cuenta
       and hi.fecha >= trunc(v_fec_proceso,'mm');
    	  
     exception
        when others then
           null;     
     end;   
    if v_contador = 100 then
       --commit ;
     v_contador := 0 ;
    end if ;   
    end loop;  
    --commit ;
    -- Activo los triggers.
    EXECUTE IMMEDIATE ('alter trigger tb_cx_fianzas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_fianzas enable');
  end;

-- Inicio del proceso principal
BEGIN
  if v_gen_pro_cam_ofi_cuentas = 'S' then
    lp_act_ofi_cta_cda_bonos;
    lp_act_ofi_cta_ahorro;
    lp_act_ofi_cta_cta_corriente;
    lp_act_ofi_cta_tarjetas;
    lp_act_ofi_cta_prestamos;
    lp_act_ofi_cta_ope_vencidas;
    lp_act_ofi_cta_cx_cta_cobran;
    lp_act_ofi_cta_cx_cta_export;
    lp_act_ofi_cta_cx_cta_import;
    lp_act_ofi_cta_cx_fianzas;
  end if;
  
  -- Requerimiento: CNFDEEVO-30.
  -- Fecha: 04/03/2016.
  -- prg_act_par_dinamico('GEN_PRO_CAM_OFI_CUENTAS', null, null, null, null, 'N');

EXCEPTION
  WHEN OTHERS THEN
    EXECUTE IMMEDIATE ('alter trigger tb_ah_cta_certificados enable');
    EXECUTE IMMEDIATE ('alter trigger ta_ah_cta_certificados enable');  
    EXECUTE IMMEDIATE ('alter trigger tb_ah_cta_vistas enable');  
    EXECUTE IMMEDIATE ('alter trigger tb_cc_cta_corrientes enable');
    EXECUTE IMMEDIATE ('alter trigger ab_ta_cta_tarjetas enable');
    EXECUTE IMMEDIATE ('alter trigger tb_pr_cta_prestamos enable');
    EXECUTE IMMEDIATE ('alter trigger ta_pr_cta_prestamos enable');
    EXECUTE IMMEDIATE ('alter trigger ta_ov_cta_vencidas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_ov_cta_vencidas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_ov_sal_mensuales enable');
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_cobranzas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_cobranzas enable');
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_exportaciones enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_exportaciones enable');
    EXECUTE IMMEDIATE ('alter trigger tb_cx_cta_importaciones enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_cta_importaciones enable');
    EXECUTE IMMEDIATE ('alter trigger tb_cx_fianzas enable');
    EXECUTE IMMEDIATE ('alter trigger ab_cx_fianzas enable');
    
    raise_application_error(-20001, ' Error en el proceso prg_pro_cam_ofi_cuantas.'|| ' - ' || SQLERRM);
END;
/

