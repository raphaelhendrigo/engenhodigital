"""Home screen for Engenho Digital app."""

from kivy.properties import ListProperty, StringProperty
from kivy.uix.screenmanager import Screen


class HomeScreen(Screen):
    """Landing screen presenting Engenho Digital."""

    intro_title = StringProperty("Engenho Digital")
    intro_subtitle = StringProperty("Projetos & Sistemas")
    intro_description = StringProperty(
        "Tecnologia, inovacao e produtos digitais feitos sob medida "
        "para impulsionar negocios."
    )

    hero_title = StringProperty("Engenharia de software & projetos eletricos")
    hero_subtitle = StringProperty("Solucoes digitais e eletricas")
    hero_tagline = StringProperty(
        "para tirar seus projetos do papel."
    )
    hero_body = StringProperty(
        "A Engenho Digital integra desenvolvimento de softwares sob medida, "
        "projetos eletricos em CAD/CAM e automacao de processos. "
        "Combinamos engenharia, dados e experiencia em campo para entregar "
        "solucoes enxutas, modernas e prontas para producao."
    )

    cta_primary = StringProperty("Agendar conversa tecnica")
    cta_secondary = StringProperty("Ver projetos em destaque \u2192")

    stats = ListProperty(
        [
            {"value": "+10", "label": "Anos com tecnologia"},
            {"value": "Full-stack", "label": "Web / APIs / Data"},
            {"value": "CAD/CAM", "label": "Projetos eletricos detalhados"},
        ]
    )

    pillars = ListProperty(
        [
            {
                "title": "Software sob medida",
                "description": "Sistemas web em Flask, React e cloud com automacao, dashboards e integracoes.",
            },
            {
                "title": "Projetos eletricos CAD/CAM",
                "description": "Plantas, diagramas e detalhamento tecnico para obras e industria.",
            },
            {
                "title": "Consultoria em dados e automacao",
                "description": "Uso de dados para reduzir retrabalho, padronizar processos e ganhar previsibilidade.",
            },
        ]
    )

    profiles = ListProperty(
        [
            {
                "name": "Raphael Hendrigo de Souza Goncalves",
                "role": "Engenharia & Dados",
                "bullets": [
                    "Lideranca tecnica em solucoes web, automacao e analytics.",
                    "Pos-graduando em Ciencia de Dados (USP ICMC).",
                    "Transforma dados operacionais em insights acionaveis.",
                ],
            },
            {
                "name": "Edgar de Almeida",
                "role": "Projetos Eletricos & CAD/CAM",
                "bullets": [
                    "Especialista em plantas, diagramas e detalhamento executivo.",
                    "Coordena listas de materiais e quadros de cargas.",
                    "Foco em conformidade tecnica e eficiencia energetica.",
                ],
            },
        ]
    )

    highlight_projects = ListProperty(
        [
            {
                "category": "Software \u00b7 Gestao",
                "title": "Portal de Automacao de Processos Internos",
                "summary": "Sistema web em Python/Flask integrado a nuvem para demandas, documentos e paineis.",
                "bullets": [
                    "Reduz retrabalho e garante rastreabilidade.",
                    "Relatorios e historico completo de execucao.",
                    "Exportacao rapida de documentos.",
                ],
            },
            {
                "category": "Eletrica \u00b7 CAD/CAM",
                "title": "Projeto Eletrico de Escritorio Corporativo",
                "summary": "Plantas, diagramas e quadros de cargas para implantacao com eficiencia energetica.",
                "bullets": [
                    "Layouts em CAD com revisoes controladas.",
                    "Documentacao pronta para aprovacao.",
                    "Lista de materiais organizada por ambiente.",
                ],
            },
            {
                "category": "Dados \u00b7 Automacao",
                "title": "Monitoramento de Indicadores Tecnicos",
                "summary": "Pipeline de dados centralizando metricas para decisoes rapidas e baseadas em evidencias.",
                "bullets": [
                    "Integracao de multiplas fontes de dados.",
                    "Atualizacao automatica de metricas.",
                    "Visualizacao clara para times tecnicos e gestores.",
                ],
            },
        ]
    )
