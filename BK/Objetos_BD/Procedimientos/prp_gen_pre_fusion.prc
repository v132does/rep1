create or replace procedure it.prp_gen_pre_fusion(p_nro_cuenta pr_cta_prestamos.nro_cuenta%type default null) is

   /* insertar registros en la tabla de previsiones de prestamos. */
   procedure lp_ins_prevision(rp_pprev in pr_previsiones%rowtype);

   v_fec_varchar       ge_calendarios.fec_actual%type:=pag_cal.fu_obt_fec_actual(1);
   v_fec_actual        varchar2(30);
   v_cod_mon_local     ba_monedas.cod_moneda%type;
   v_prevision         pr_previsiones.monto%type;
   r_pprev             pr_previsiones%rowtype;
   r_gmovi             ge_movimientos%rowtype;
   v_nro_secuencia     ge_movimientos.nro_secuencia%type;
   v_hora              ge_movimientos.hora%type;
   v_por_prevision     number(18, 2);
   v_redondeo          number(2);
   v_mto_pre_total     pr_previsiones.mto_pre_total%type;
   v_pre_req_fusion    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PRE_REQ_FUSION');
   v_pre_pla_20_anhos  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PRE_PLA_20_ANHOS');
   v_fec_ini_fusion    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('FEC_INI_DIF');
   v_prv_dia           pr_previsiones.mto_pre_total%type;
   v_prv_diferida      pr_previsiones.mto_pre_total%type;
   v_prv_dif_anterior  pr_previsiones.mto_pre_total%type;
   v_prv_ant_prest     pr_previsiones.mto_pre_total%type;
   v_prv_dia_ant       pr_previsiones.mto_pre_total%type;
   v_dia_residual      pr_previsiones.mto_pre_total%type;
   v_cal_fecha         number(4);
   v_cal_extorno       number(4);

   

    TYPE mov_rec IS RECORD (
        nro_cuenta         VARCHAR2(20),
        sal_capital        NUMBER,
        sal_interes        NUMBER,
        cod_moneda         VARCHAR2(3),
        cod_modalidad      VARCHAR2(3),
        nro_solicitud      NUMBER,
        cod_oficina        VARCHAR2(10),
        dev_no_cobrado     NUMBER,
        cod_modulo         VARCHAR2(10),
        sal_int_adelantado NUMBER,
        estado             VARCHAR2(1),
        est_batch          VARCHAR2(1),
        oc_ttdeuda         NUMBER
    );

   TYPE t_mov_rec IS TABLE OF mov_rec;
    v_prestamos t_mov_rec;

    TYPE mov_rec2 IS RECORD (
        nro_cuenta         pr_cta_prestamos.nro_cuenta%TYPE,
        sal_capital        NUMBER,
        sal_interes        NUMBER,
        cod_moneda         VARCHAR2(3),
        cod_modalidad      VARCHAR2(3),
        nro_solicitud      NUMBER,
        cod_oficina        VARCHAR2(10),
        dev_no_cobrado     NUMBER,
        cod_modulo         VARCHAR2(10),
        sal_int_adelantado NUMBER,
        estado             VARCHAR2(1),
        est_batch          VARCHAR2(1),
        oc_ttdeuda         NUMBER
    );

    TYPE t_mov_rec2 IS TABLE OF mov_rec2;
    v_diferidos t_mov_rec2; 
    

    -- Declaración de variables y cursor
    type t_nro_cuenta_tab is table of pr_previsiones.nro_cuenta%type index by pls_integer;
    v_nro_cuentas t_nro_cuenta_tab;

    type rc_ge_cla_oper is record(mto_pre_total  ge_cla_operaciones.mto_pre_total%type,
                                    nro_cuenta ge_cla_operaciones.nro_cuenta%type);
    TYPE typ_ge_cla_oper is TABLE OF rc_ge_cla_oper;
    rg_ge_cla_oper typ_ge_cla_oper := typ_ge_cla_oper();
        
    type rc_ge_cla_operaciones is record(tot_prevision ge_cla_operaciones.tot_prevision%type,
                                    mto_pre_total  ge_cla_operaciones.mto_pre_total%type,
                                    nro_cuenta ge_cla_operaciones.nro_cuenta%type);
    TYPE typ_ge_cla_operaciones is TABLE OF rc_ge_cla_operaciones;
    rg_ge_cla_operaciones typ_ge_cla_operaciones := typ_ge_cla_operaciones();

   cursor c_prestamos is
      select p.nro_cuenta,
             nvl(p.sal_capital, 0) sal_capital,
             nvl(p.sal_interes, 0) sal_interes,
             p.cod_moneda,
             p.cod_modalidad,
             p.nro_solicitud,
             p.cod_oficina,
             nvl(p.dev_no_cobrado, 0) dev_no_cobrado,
             p.cod_modulo,
             nvl(p.sal_int_adelantado, 0) sal_int_adelantado,
             p.estado,
             p.est_batch,
             nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0) oc_ttdeuda
        from pr_cta_prestamos      p,
             it.ge_cta_dat_fusion  b
       where p.cod_modulo = b.cod_modulo
         and p.nro_cuenta = b.nro_cuenta
         and p.estado not in ('N')
         and b.procesado  = 'N'
         and (p.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null);

       cursor c_diferidos is
      select p.nro_cuenta,
             nvl(p.sal_capital, 0) sal_capital,
             nvl(p.sal_interes, 0) sal_interes,
             p.cod_moneda,
             p.cod_modalidad,
             p.nro_solicitud,
             p.cod_oficina,
             nvl(p.dev_no_cobrado, 0) dev_no_cobrado,
             p.cod_modulo,
             nvl(p.sal_int_adelantado, 0) sal_int_adelantado,
             p.estado,
             p.est_batch,
             nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0) oc_ttdeuda
        from pr_cta_prestamos      p,
             it.ge_cta_dat_fusion  b
       where p.cod_modulo = b.cod_modulo
         and p.nro_cuenta = b.nro_cuenta
         and p.estado not in ('N')
         and (p.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null);

      cursor c_del_prevision is
      select a.nro_cuenta
       from pr_previsiones a, it.ge_cta_dat_fusion b
       where a.nro_cuenta = b.nro_cuenta
         and a.fecha = v_fec_actual;

   /* obtener prevision anterior. */
   function lf_obt_prv_ant_acum
   (
      p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type,
      p_fec_actual in date
   ) return number is
      v_monto pr_previsiones.mto_pre_total%type;
   begin
      select nvl(mto_pre_total, 0)
        into v_monto
        from pr_previsiones
       where nro_cuenta = p_nro_cuenta
         and fecha = (select max(fecha)
                       from pr_previsiones
                               where nro_cuenta = p_nro_cuenta
                                 and fecha < p_fec_actual);

      return v_monto;
   end;

   /* insertar registros en la tabla de previsiones de prestamos. */
   procedure lp_ins_prevision(rp_pprev in pr_previsiones%rowtype) is
   begin
      insert into pr_previsiones
         (fecha, nro_cuenta, monto, sal_capital, dev_no_cobrado, porcentaje, mto_pre_total)
      values
         (rp_pprev.fecha, rp_pprev.nro_cuenta, rp_pprev.monto, rp_pprev.sal_capital,
          rp_pprev.dev_no_cobrado, rp_pprev.porcentaje,rp_pprev.mto_pre_total);
   exception
      when others then
         raise_application_error(-20000, 'Ins.Prev. ' || sqlerrm);
   end;


begin
   v_fec_actual         := to_char(v_fec_varchar,'DD/MM/YYYY');
   v_hora               := fug_ini_hora(sysdate);
   v_hora               := pag_gen.fu_obt_sig_segundo(v_hora);
   v_hora               := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   v_cod_mon_local      := pag_gen.fu_obt_mon_local;
   v_nro_secuencia      := 0;

    -- Cargar los datos en la colección --
    open c_del_prevision;
    fetch c_del_prevision bulk collect into v_nro_cuentas;
    close c_del_prevision;

   if v_pre_req_fusion = 'S' then --Limpiar previsiones de la fecha
    -- Realizar el DELETE en lote usando FORALL --
    forall i in v_nro_cuentas.first .. v_nro_cuentas.last
           delete 
           from pr_previsiones b
           where b.fecha= v_fec_actual
           and   b.nro_cuenta = v_nro_cuentas(i);
   end if;

    -- Abrir el primer cursor y realizar el BULK COLLECT
    OPEN c_prestamos;
    FETCH c_prestamos BULK COLLECT INTO v_prestamos;
    CLOSE c_prestamos;


    if v_pre_req_fusion = 'S' then
        FOR k IN 1 .. v_prestamos.COUNT LOOP
          
        begin
          select d.val_parametro
            into v_redondeo
            from ge_par_dinamicos d
           where d.parametro = 'VAL_RED_MON_EXTRANJERA'
             and nvl(d.cod_modulo,nvl(6,-1)) = nvl(6,-1)             
             and nvl(d.cod_modalidad,nvl(null,-1)) = nvl(null,-1)                        
             and d.cod_moneda = v_prestamos(k).cod_moneda;
        exception
          when others then
            v_redondeo := 0;
        end;        
          
         r_pprev.mto_pre_total := 0;
         v_prevision     := 0;
         v_mto_pre_total := 0;
         v_por_prevision := 100;
         v_prevision     := round(nvl(v_prestamos(k).oc_ttdeuda, 0)  * v_por_prevision / 100, v_redondeo);

         -- inicializar datos cabecera del movimiento
         r_gmovi.cod_usuario    := user;
         r_gmovi.hora           := v_hora;
         r_gmovi.fecha          := v_fec_actual;
         r_gmovi.fec_valor      := v_fec_actual;
         r_gmovi.cod_mod_padre  := v_prestamos(k).cod_modulo;
         r_gmovi.cod_mad_padre  := v_prestamos(k).cod_modalidad;
         r_gmovi.cod_modulo     := v_prestamos(k).cod_modulo;
         r_gmovi.cod_modalidad  := v_prestamos(k).cod_modalidad;
         r_gmovi.cod_oficina    := v_prestamos(k).cod_oficina;
         r_gmovi.cod_ofi_origen := v_prestamos(k).cod_oficina;
         r_gmovi.cod_moneda     := v_prestamos(k).cod_moneda;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.protegido      := 'N';
         r_gmovi.nro_cuenta     := v_prestamos(k).nro_cuenta;
         r_gmovi.est_cuenta     := v_prestamos(k).estado;
         if v_nro_secuencia + 2 > 800 then
            v_nro_secuencia := 0;
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
            r_gmovi.hora    := v_hora;
         end if;
         --insertar movimiento
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.cod_tra_padre       := 779;
         r_gmovi.cod_transaccion     := 779;
         r_gmovi.concepto            := 'CONST. PREV A DIFERIR 100%';
         r_gmovi.monto               := nvl(v_prevision, 0);
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

           --- insertar prevision
         r_pprev.nro_cuenta          := v_prestamos(k).nro_cuenta;
         r_pprev.fecha               := v_fec_actual;
         r_pprev.monto               := 0;
         r_pprev.sal_capital         := nvl(v_prestamos(k).sal_capital, 0);
         r_pprev.dev_no_cobrado      := nvl(v_prestamos(k).dev_no_cobrado, 0);
         r_pprev.porcentaje          := nvl(v_por_prevision, 0);
         r_pprev.mto_pre_total       := nvl(v_prevision, 0);
         lp_ins_prevision(r_pprev);

                                                                                                                             
         begin --Marca como procesado
           update it.ge_cta_dat_fusion t
           set t.procesado='S'
           where t.nro_cuenta=v_prestamos(k).nro_cuenta
           and   t.cod_modulo=v_prestamos(k).cod_modulo;
         end;

        rg_ge_cla_oper.EXTEND;
        rg_ge_cla_oper(rg_ge_cla_oper.COUNT).nro_cuenta := v_prestamos(k).nro_cuenta;
        rg_ge_cla_oper(rg_ge_cla_oper.COUNT).mto_pre_total := v_prevision;    
      end loop;
    --FORALL n IN INDICES OF rg_ge_cla_oper
    forall n in rg_ge_cla_oper.first .. rg_ge_cla_oper.last    
          update  ge_cla_operaciones
            set tot_prevision            = 0,
                mto_pre_total            = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,
                                             nvl(rg_ge_cla_oper(n).mto_pre_total, 0))
          where nro_cuenta = rg_ge_cla_oper(n).nro_cuenta;
    end if;

    OPEN c_diferidos;
    FETCH c_diferidos BULK COLLECT INTO v_diferidos;
    CLOSE c_diferidos;

   if v_pre_req_fusion = 'N' then
     FOR m IN 1 .. v_diferidos.COUNT LOOP
       
       begin
          select c.val_parametro
            into v_redondeo
            from ge_par_dinamicos c
           where c.parametro = 'VAL_RED_MON_EXTRANJERA'
             and nvl(c.cod_modulo,nvl(6,-1)) = nvl(6,-1)                          
             and nvl(c.cod_modalidad,nvl(null,-1)) = nvl(null,-1)                                                    
             and c.cod_moneda = v_diferidos(m).cod_moneda;
        exception
          when others then
            v_redondeo := 0;
        end;      

         -- inicializar datos cabecera del movimiento
         r_gmovi.cod_usuario    := user;
         r_gmovi.hora           := v_hora;
         r_gmovi.fecha          := v_fec_actual;
         r_gmovi.fec_valor      := v_fec_actual;
         r_gmovi.cod_mod_padre  := v_diferidos(m).cod_modulo;
         r_gmovi.cod_mad_padre  := v_diferidos(m).cod_modalidad;
         r_gmovi.cod_modulo     := v_diferidos(m).cod_modulo;
         r_gmovi.cod_modalidad  := v_diferidos(m).cod_modalidad;
         r_gmovi.cod_oficina    := v_diferidos(m).cod_oficina;
         r_gmovi.cod_ofi_origen := v_diferidos(m).cod_oficina;
         r_gmovi.cod_moneda     := v_diferidos(m).cod_moneda;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.protegido      := 'N';
         r_gmovi.nro_cuenta     := v_diferidos(m).nro_cuenta;
         r_gmovi.est_cuenta     := v_diferidos(m).estado;
         if v_nro_secuencia + 2 > 800 then
            v_nro_secuencia     := 0;
            v_hora              := pag_gen.fu_obt_sig_segundo(v_hora);
            v_hora              := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
            r_gmovi.hora        := v_hora;
         end if;
         
         v_prv_ant_prest        := lf_obt_prv_ant_acum(v_diferidos(m).nro_cuenta,v_fec_actual) ; --prevision diferida anterior
         v_cal_fecha            := to_date(v_fec_actual,'DD/MM/YYYY') - to_date(v_fec_ini_fusion,'DD/MM/YYYY') ; --dias transcurrido desde el inicio
         v_cal_extorno          := to_date(v_fec_actual,'DD/MM/YYYY') - (to_date(v_fec_ini_fusion,'DD/MM/YYYY')+1) ;--debe extornar a partir del dia 2
         v_dia_residual         := v_pre_pla_20_anhos - v_cal_extorno; --plazo residual
         v_prv_dia              := round(v_prv_ant_prest / v_dia_residual ,v_redondeo); --valor diario a diferir
         if  v_prv_dia <=0 and v_diferidos(m).cod_moneda='GS'  then
         v_prv_dia              :=1;
         elsif  v_prv_dia <=0 and v_diferidos(m).cod_moneda='USD' then
         v_prv_dia              :=0.01;
         end if;
         v_prv_diferida         := round (v_prv_dia*v_cal_fecha,v_redondeo ) ; -- perdida diaria diferido a 20 años
         v_prv_dia_ant          := v_prv_diferida - v_prv_dia; --valor a desafectar- diariamente
         v_prv_dif_anterior     := v_prv_ant_prest - v_prv_dia   ; -- mto_pre_total diario

       -- insertar prevision
         r_pprev.nro_cuenta          := v_diferidos(m).nro_cuenta;
         r_pprev.fecha               := v_fec_actual;
         r_pprev.monto               := v_prv_diferida;
         r_pprev.mto_pre_total       := nvl(v_prv_dif_anterior, 0);
         r_pprev.sal_capital         := nvl(v_diferidos(m).sal_capital, 0);
         r_pprev.dev_no_cobrado      := nvl(v_diferidos(m).dev_no_cobrado, 0);
         r_pprev.porcentaje          := nvl(v_por_prevision, 0);

         lp_ins_prevision(r_pprev);

       --inserta movimiento
         if v_cal_extorno >0 then  -- extorna a partir del dia 2

            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.monto               := nvl(-v_prv_dia_ant, 0);
            r_gmovi.cod_tra_padre       := 725;
            r_gmovi.cod_transaccion     := 725;
            r_gmovi.concepto            := 'EXTORNO PREVISIONES DIFERIDAS';

            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         end if;

            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.monto               := nvl(v_prv_diferida, 0);
            r_gmovi.cod_tra_padre       := 725;
            r_gmovi.cod_transaccion     := 725;
            r_gmovi.concepto            := 'PREVISIONES DIFERIDAS';

            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        
        rg_ge_cla_operaciones.EXTEND;
        rg_ge_cla_operaciones(rg_ge_cla_operaciones.COUNT).nro_cuenta := v_diferidos(m).nro_cuenta;
        rg_ge_cla_operaciones(rg_ge_cla_operaciones.COUNT).tot_prevision := v_prv_diferida;
        rg_ge_cla_operaciones(rg_ge_cla_operaciones.COUNT).mto_pre_total := v_prv_dif_anterior;
 
     end loop;
     
    -- Realizamos un FORALL fuera del ciclo FOR para actualizar en bloque
    forall i in rg_ge_cla_operaciones.FIRST .. rg_ge_cla_operaciones.LAST    
          update  ge_cla_operaciones
            set tot_prevision            = rg_ge_cla_operaciones(i).tot_prevision, --v_prv_diferida ,
                mto_pre_total            = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,
                                             nvl(rg_ge_cla_operaciones(i).mto_pre_total, 0))
          where nro_cuenta = rg_ge_cla_operaciones(i).nro_cuenta;
        
   end if;


end;
