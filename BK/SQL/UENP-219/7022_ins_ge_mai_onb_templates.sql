begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
/

declare

v_tip_producto number;

V_LONG_1 LONG := '<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="css/styles.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@4.3.1/dist/css/bootstrap.min.css"
        integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">
    <title>ueno Empresas</title>
</head>

<body>
    <div class="contenedor">

        <!--  Card 1 -->
        <div class="row px-3 text-center d-flex justify-content-center">
            <div class="card card-style">
                <div class="card-body">
                    <div class="row">
                        <div class="col">

                            <div class="card-content-layout">
                                <p style=""><strong> Nro. Documento Solicitante</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Nombre Solicitante</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <br>

        <!-- Card -->

        <!--  Card 2 -->
        <div class="row px-3 text-center d-flex justify-content-center">
            <div class="card card-style">
                <div class="card-body">
                    <div class="row">
                        <div class="col">
                            <div class="card-content-layout">
                                <p style=""><strong> Nro. Documento Invitado</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Nombre Invitado</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <br>

        <!--  Card -->

        <!-- Card 3 -->
        <div class="row px-3 text-center d-flex justify-content-center">
            <div class="card card-style">
                <div class="card-body">
                    <div class="row">
                        <div class="col">
                            <div class="card-content-layout">
                                <p style=""><strong> Nro. Oferta</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Fecha Oferta</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Monto Total</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Monto Proyecto</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Monto Equipamiento</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Monto Cuota</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Cantidad de Cuotas</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>

                            <div class="card-content-layout">
                                <p style=""><strong> Estado Oferta</strong></p>
                                <p style="">xxxx xxxx</p>
                            </div>
                        </div>

                    </div>
                </div>
            </div>

        </div>

        <!--   Card -->

        

    </div>


    <!-- script tags -->
    <script src="https://code.jquery.com/jquery-3.3.1.slim.min.js"
        integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo"
        crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.14.7/dist/umd/popper.min.js"
        integrity="sha384-UO2eT0CpHqdSJQ6hJty5KVphtPhzWj9WO1clHTMGa3JDZwrnQq4sF86dIHNDz0W1"
        crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.3.1/dist/js/bootstrap.min.js"
        integrity="sha384-JjSmVgyd0p3pXB1rRibZUAYoIIy6OrQ6VrjIEaFf/nJGzIxFDsf4x0xIM+B07jRM"
        crossorigin="anonymous"></script>
</body>


</html>';

begin
  select max(t.tip_producto) + 1
    into v_tip_producto
    from ge_mai_onb_templates t;

  insert into ge_mai_onb_templates
    (TIP_PRODUCTO,
     DESCRIPCION,
     ASUNTO,
     TEMPLATE,
     INI_VIGENCIA,
     FIN_VIGENCIA)
  values
    (v_tip_producto,
     'Envio de Oferta Che Roga generada',
     'Envio de Oferta Che Roga generada',
     V_LONG_1,
     trunc(sysdate),
     add_months(trunc(sysdate), 80));

  commit;

end;
